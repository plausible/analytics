defmodule Plausible.Workers.PurgeCDNCache do
  @moduledoc """
  Worker for purging CDN cache for tracker scripts on cloud.

  Uses Bunny CDN's API to purge cache by tag.
  Docs ref: https://docs.bunny.net/reference/pullzonepublic_purgecachepostbytag

  Note that purging by id "*" is equivelent to purging ALL cache.
  """

  use Oban.Worker,
    queue: :purge_cdn_cache,
    max_attempts: 5,
    # To avoid running into API rate limits, we:
    # - Schedule jobs with a delay
    # - Bump the scheduled time every time a new one is scheduled with the same args
    unique: [
      states: [:scheduled],
      fields: [:args]
    ]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    pullzone_id = Application.get_env(:plausible, __MODULE__, [])[:pullzone_id]
    api_key = Application.get_env(:plausible, __MODULE__, [])[:api_key]

    purge_cache(id, pullzone_id, api_key)
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff starting at 3 minutes
    trunc(:math.pow(2, attempt - 1) * 180)
  end

  defp purge_cache(id, pullzone_id, api_key) when is_nil(pullzone_id) or is_nil(api_key) do
    Logger.warning("Ignoring purge CDN cache for tracker script #{id}: Configuration missing")
    {:discard, "Configuration missing"}
  end

  defp purge_cache(id, pullzone_id, api_key) do
    options =
      [
        headers: [
          {"content-type", "application/json"},
          {"AccessKey", api_key}
        ],
        body: Jason.encode!(%{"CacheTag" => "tracker_script::#{id}"})
      ]
      |> Keyword.merge(Application.get_env(:plausible, __MODULE__)[:req_opts] || [])

    case Req.post("https://api.bunny.net/pullzone/#{pullzone_id}/purgeCache", options) do
      {:ok, %{status: 204}} ->
        Logger.info("Successfully purged CDN cache for tracker script #{id}")
        {:ok, :success}

      {:ok, %{status: status}} ->
        Logger.warning(
          "Failed to purge CDN cache for tracker script #{id}: Unexpected status: #{status}"
        )

        {:error, "Unexpected status: #{status}"}

      {:error, reason} ->
        Logger.warning("Failed to purge CDN cache for tracker script #{id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
