defmodule PlausibleWeb.TrackerScriptCache do
  @moduledoc """
  Cache for tracker script.

  On self-hosted instances, we cache the entire tracker script.
  On EE instances, we cache valid tracker script ids to avoid database lookups.
  """
  alias Plausible.Site.TrackerScriptConfiguration

  import Ecto.Query
  use Plausible
  use Plausible.Cache

  @cache_name :tracker_script_cache

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_tracker_script

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(TrackerScriptConfiguration, :count)
  end

  @impl true
  def base_db_query() do
    from(
      t in TrackerScriptConfiguration,
      join: s in assoc(t, :site),
      preload: [site: s]
    )
  end

  @impl true
  def get_from_source(id, opts \\ []) do
    query =
      base_db_query()
      |> where([t], t.id == ^id)

    case Plausible.Repo.one(query) do
      %TrackerScriptConfiguration{} = tracker_script_configuration ->
        cache_content(tracker_script_configuration, opts)

      _ ->
        nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      tracker_script_configuration, acc ->
        [
          {tracker_script_configuration.id, cache_content(tracker_script_configuration)}
          | acc
        ]
    end)
  end

  defp cache_content(tracker_script_configuration, opts \\ []) do
    if ce?() or Keyword.get(opts, :force_get_script, false) do
      PlausibleWeb.Tracker.build_script(tracker_script_configuration)
    else
      true
    end
  end
end
