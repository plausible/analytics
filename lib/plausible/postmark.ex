defmodule Plausible.Postmark do
  @moduledoc """
  Minimal client for the parts of Postmark's HTTP API

  See: https://postmarkapp.com/developer/api/bounce-api
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

  @spec suppressing_bounce_types() :: [String.t()]
  def suppressing_bounce_types(), do: Map.keys(@suppressing_bounce_types)

  @bounces_page_size 500
  @bounces_max_total 10_000

  @doc """
  https://postmarkapp.com/developer/api/bounce-api#get-bounces
  """
  @spec list_bounces(map()) :: {:ok, [map()]} | {:error, term()}
  def list_bounces(params \\ %{}) do
    list_bounces(params, 0, [])
  end

  @doc """
  https://postmarkapp.com/developer/api/bounce-api#activate-a-bounce
  """
  @spec activate_bounce(integer()) :: {:ok, map()} | {:error, term()}
  def activate_bounce(bounce_id) do
    put("/bounces/#{bounce_id}/activate")
  end

  defp list_bounces(params, offset, acc) do
    query = Map.merge(params, %{count: @bounces_page_size, offset: offset})

    case get("/bounces", query) do
      {:ok, %{"Bounces" => bounces, "TotalCount" => total_count}} ->
        acc = acc ++ bounces
        next_offset = offset + @bounces_page_size

        if bounces == [] or length(acc) >= total_count or next_offset >= @bounces_max_total do
          {:ok, acc}
        else
          list_bounces(params, next_offset, acc)
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  One-off backfill of e-mail suppressions from Postmark's Bounce API.

  Postmark returns one record per bounce *event*, not per address, so the
  same address can show up more than once (e.g. hard-bounced once and blocked separately).
  Reported `processed` (raw events fetched) and `distinct_addresses` (addresses
  actually upserted, one row each) can therefore differ.

  Postmark doesn't document a sort order for these, so we employ
  our own winner picking mechanism (see `pick_winner/1`).
  """
  @spec backfill_suppressions() :: %{
          processed: non_neg_integer(),
          distinct_addresses: non_neg_integer(),
          upsert_errors: non_neg_integer(),
          fetch_errors: non_neg_integer()
        }
  def backfill_suppressions() do
    types = suppressing_bounce_types() ++ ["SpamComplaint"]

    {fetch_errors, events} =
      Enum.reduce(types, {0, []}, fn type, {fetch_errors, events} ->
        case fetch_type(type) do
          {:error, _reason} -> {fetch_errors + 1, events}
          {:ok, type_events} -> {fetch_errors, events ++ type_events}
        end
      end)

    winners =
      events
      |> Enum.group_by(fn {_type, bounce} -> String.downcase(bounce["Email"]) end)
      |> Map.values()
      |> Enum.map(&pick_winner/1)

    {:ok, upsert_results} =
      Plausible.Repo.transact(fn ->
        {:ok, Enum.map(winners, fn {type, bounce} -> upsert_suppression(bounce, type) end)}
      end)

    %{
      processed: length(events),
      distinct_addresses: length(winners),
      upsert_errors: Enum.count(upsert_results, &match?({:error, _}, &1)),
      fetch_errors: fetch_errors
    }
  end

  defp fetch_type(type) do
    case list_bounces(%{type: type}) do
      {:ok, bounces} ->
        {:ok, Enum.map(bounces, &{type, &1})}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch Postmark bounces for backfill, type=#{type}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Spam complaint always wins regardless of timing.
  # Otherwise, the most recent event wins, since it best reflects
  # the address' current state (Postmark's `Inactive`/`CanActivate` flags
  # can change between events for the same address).
  defp pick_winner(events) do
    {spam_complaints, bounces} =
      Enum.split_with(events, fn {type, _bounce} -> type == "SpamComplaint" end)

    candidates = if spam_complaints != [], do: spam_complaints, else: bounces

    Enum.max_by(candidates, fn {_type, bounce} -> bounced_at(bounce) end)
  end

  defp bounced_at(bounce) do
    with bounced_at when is_binary(bounced_at) <- bounce["BouncedAt"],
         {:ok, datetime, _utc_offset} <- DateTime.from_iso8601(bounced_at) do
      datetime
    else
      # missing/invalid = oldest
      _ -> DateTime.from_unix!(0)
    end
  end

  defp upsert_suppression(bounce, "SpamComplaint") do
    bounce
    |> suppression_attrs()
    |> EmailSuppressions.create_from_spam_complaint()
  end

  defp upsert_suppression(bounce, type) do
    {:ok, reason} = suppressing_reason(type)

    bounce
    |> suppression_attrs()
    |> Map.put(:reason, reason)
    |> EmailSuppressions.create_from_bounce()
  end

  defp suppression_attrs(bounce) do
    %{
      email: bounce["Email"],
      source: :backfill,
      postmark_bounce_id: bounce["ID"],
      postmark_inactive: bounce["Inactive"] || false,
      can_activate: bounce["CanActivate"] || false,
      details: bounce["Details"]
    }
  end

  defp get(path, params) do
    request(&Req.get/2, path, params: params)
  end

  defp put(path) do
    request(&Req.put/2, path, [])
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
