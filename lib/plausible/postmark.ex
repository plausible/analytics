defmodule Plausible.Postmark do
  @moduledoc """
  Minimal client for the parts of Postmark's HTTP API

  See: https://postmarkapp.com/developer/api/bounce-api and
  https://postmarkapp.com/developer/api/suppressions-api
  """

  require Logger

  @base_api_url "https://api.postmarkapp.com"

  # https://postmarkapp.com/developer/api/bounce-api#bounce-types
  @suppressing_bounce_types %{
    "HardBounce" => :hard_bounce,
    "BadEmailAddress" => :bad_email_address,
    "Blocked" => :blocked,
    "SpamNotification" => :spam_notification,
    "Unsubscribe" => :unsubscribe
  }

  @spec suppressing_reason(String.t()) :: {:ok, atom()} | :error
  def suppressing_reason(type), do: Map.fetch(@suppressing_bounce_types, type)

  @streams ["outbound", "priority", "untrusted-recipients"]

  @doc """
  https://postmarkapp.com/developer/api/suppressions-api#delete-a-suppression

  Lifts a suppression on every stream we send from.
  Postmark refuses this only for a spam complaint.
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

  # Potsmark limit
  @delete_chunk_size 50

  @doc """
  Best-effort delete many suppressions at once, across every stream.
  """
  @spec delete_suppressions([String.t()]) :: [String.t()]
  def delete_suppressions([]), do: []

  def delete_suppressions(emails) do
    emails
    |> Enum.chunk_every(@delete_chunk_size)
    |> Enum.flat_map(&delete_suppressions_chunk/1)
  end

  defp delete_suppressions_chunk(chunk) do
    if @streams |> Enum.map(&delete_suppressions_chunk(&1, chunk)) |> Enum.all?() do
      chunk
    else
      []
    end
  end

  defp delete_suppressions_chunk(stream, emails) do
    # https://postmarkapp.com/developer/api/suppressions-api#delete-a-suppression
    case post("/message-streams/#{stream}/suppressions/delete", %{
           "Suppressions" => Enum.map(emails, &%{"EmailAddress" => &1})
         }) do
      {:ok, %{"Suppressions" => results}} ->
        case Enum.filter(results, &(&1["Status"] == "Failed")) do
          [] ->
            :ok

          failed ->
            Logger.warning(
              "Failed to delete some Postmark suppressions, stream=#{stream}: #{inspect(failed)}"
            )
        end

        true

      {:error, reason} ->
        Logger.error(
          "Failed to delete a batch of #{length(emails)} Postmark suppressions, stream=#{stream}: #{inspect(reason)}"
        )

        false
    end
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
