defmodule Plausible.Postmark do
  @moduledoc """
  Minimal client for the parts of Postmark's HTTP API

  See: https://postmarkapp.com/developer/api/bounce-api and
  https://postmarkapp.com/developer/api/suppressions-api
  """

  require Logger

  alias Plausible.EmailSuppressions

  @base_api_url "https://api.postmarkapp.com"

  # https://postmarkapp.com/developer/api/bounce-api#bounce-types
  @suppressing_bounce_types %{
    "HardBounce" => :hard_bounce,
    "BadEmailAddress" => :bad_email_address,
    "Blocked" => :blocked,
    "SpamNotification" => :spam_notification
  }

  @spec suppressing_reason(String.t()) :: {:ok, atom()} | :error
  def suppressing_reason(type), do: Map.fetch(@suppressing_bounce_types, type)

  @streams ["outbound", "priority"]

  @suppression_reasons %{
    "HardBounce" => :hard_bounce,
    "SpamComplaint" => :spam_complaint
  }

  @doc """
  https://postmarkapp.com/developer/api/suppressions-api#delete-a-suppression

  Lifts a suppression on every stream we send from - we don't track which
  one it's actually on, and deleting a suppression that isn't there is a
  harmless no-op per Postmark. Postmark refuses this only for a spam
  complaint; callers should check `reason` before calling this.
  """
  @spec delete_suppression(String.t()) :: :ok | {:error, term()}
  def delete_suppression(email) do
    @streams
    |> Enum.map(&delete_suppression(&1, email))
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end

  defp delete_suppression(stream, email) do
    case post("/message-streams/#{stream}/suppressions/delete", %{
           "Suppressions" => [%{"EmailAddress" => email}]
         }) do
      {:ok, %{"Suppressions" => [%{"Status" => "Deleted"}]}} ->
        :ok

      {:ok, %{"Suppressions" => [%{"Status" => "Failed", "Message" => message}]}} ->
        {:error, {stream, message}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  One-off backfill of e-mail suppressions from Postmark's Suppressions API,
  across every message stream we send from.

  If an address suppressed on more than one stream is reported once,
  we pick the winner ourselves - see: `pick_winner/1`
  """
  @spec backfill_suppressions() :: %{
          processed: non_neg_integer(),
          distinct_addresses: non_neg_integer(),
          upsert_errors: non_neg_integer(),
          fetch_errors: non_neg_integer()
        }
  def backfill_suppressions() do
    {fetch_errors, suppressions} =
      Enum.reduce(@streams, {0, []}, fn stream, {fetch_errors, suppressions} ->
        case fetch_stream(stream) do
          {:error, _reason} -> {fetch_errors + 1, suppressions}
          {:ok, stream_suppressions} -> {fetch_errors, suppressions ++ stream_suppressions}
        end
      end)

    winners =
      suppressions
      |> Enum.group_by(&String.downcase(&1["EmailAddress"]))
      |> Map.values()
      |> Enum.map(&pick_winner/1)

    {:ok, upsert_results} =
      Plausible.Repo.transact(fn ->
        {:ok, Enum.map(winners, &upsert_suppression/1)}
      end)

    %{
      processed: length(suppressions),
      distinct_addresses: length(winners),
      upsert_errors: Enum.count(upsert_results, &match?({:error, _}, &1)),
      fetch_errors: fetch_errors
    }
  end

  defp fetch_stream(stream) do
    case get("/message-streams/#{stream}/suppressions/dump", %{}) do
      {:ok, %{"Suppressions" => suppressions}} ->
        {:ok, suppressions}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch Postmark suppressions for backfill, stream=#{stream}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Spam complaint always wins regardless of timing. Otherwise, the most
  # recent one wins, since it best reflects the address' current state.
  defp pick_winner(entries) do
    {spam_complaints, others} =
      Enum.split_with(entries, &(&1["SuppressionReason"] == "SpamComplaint"))

    candidates = if spam_complaints != [], do: spam_complaints, else: others

    Enum.max_by(candidates, &created_at/1)
  end

  defp created_at(entry) do
    with created_at when is_binary(created_at) <- entry["CreatedAt"],
         {:ok, datetime, _utc_offset} <- DateTime.from_iso8601(created_at) do
      datetime
    else
      # missing/invalid = oldest
      _ -> DateTime.from_unix!(0)
    end
  end

  defp upsert_suppression(entry) do
    %{
      email: entry["EmailAddress"],
      source: :backfill,
      reason: suppression_reason(entry),
      details: "Postmark suppression (origin: #{entry["Origin"]})"
    }
    |> EmailSuppressions.create_from_bounce()
  end

  # Postmark's API has no distinct "Unsubscribe" value - the dashboard shows
  # that label for a ManualSuppression whose Origin is the recipient themself.
  defp suppression_reason(%{"SuppressionReason" => "ManualSuppression", "Origin" => "Recipient"}) do
    :unsubscribe
  end

  defp suppression_reason(%{"SuppressionReason" => "ManualSuppression"}), do: :manual

  defp suppression_reason(%{"SuppressionReason" => reason}) do
    # :manual as a fallback: Postmark only documents HardBounce/SpamComplaint/
    # ManualSuppression, but an unrecognized reason shouldn't crash the backfill
    Map.get(@suppression_reasons, reason, :manual)
  end

  defp get(path, params) do
    request(&Req.get/2, path, params: params)
  end

  defp post(path, body) do
    request(&Req.post/2, path, json: body)
  end

  defp request(req_fun, path, opts) do
    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []

    opts =
      [headers: [{"accept", "application/json"}, {"x-postmark-server-token", api_key()}]]
      |> Keyword.merge(opts)
      |> Keyword.merge(extra_opts)

    case req_fun.(@base_api_url <> path, opts) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key(), do: Keyword.fetch!(config(), :api_key)

  defp config(), do: Application.fetch_env!(:plausible, __MODULE__)
end
