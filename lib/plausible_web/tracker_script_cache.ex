defmodule PlausibleWeb.TrackerScriptCache do
  @moduledoc """
  Cache for tracker script(s) for self-hosted Plausible instances.
  """
  alias Plausible.Site.TrackerScriptConfiguration

  import Ecto.Query
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
  def get_from_source(id) do
    query =
      base_db_query()
      |> where([t], t.id == ^id)

    case Plausible.Repo.one(query) do
      %TrackerScriptConfiguration{} = tracker_script_configuration ->
        PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)

      _ ->
        nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      tracker_script_configuration, acc ->
        [
          {tracker_script_configuration.id,
           PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)}
          | acc
        ]
    end)
  end
end
