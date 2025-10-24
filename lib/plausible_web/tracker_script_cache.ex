defmodule PlausibleWeb.TrackerScriptCache do
  @moduledoc """
  Cache for tracker script.

  On self-hosted instances, we cache the entire tracker script.
  On EE instances, we cache valid tracker script ids to avoid database lookups.
  """
  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.Tracker

  import Ecto.Query
  use Plausible
  use Plausible.Cache

  @cache_name :tracker_script_cache

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_tracker_script

  on_ee do
    @doc "Caches that the config exists"
    def cache_content(%TrackerScriptConfiguration{} = _tracker_script_configuration), do: true
  else
    @doc "Caches the full tracker script"
    def cache_content(
          %TrackerScriptConfiguration{site: %{domain: _domain}} = tracker_script_configuration
        ),
        do: Tracker.build_script(tracker_script_configuration)
  end

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(TrackerScriptConfiguration, :count)
  end

  @impl true
  def base_db_query(), do: Tracker.get_tracker_script_configuration_base_query()

  @impl true
  def get_from_source(id) do
    case Tracker.get_tracker_script_configuration_by_id(id) do
      %TrackerScriptConfiguration{site: %{domain: _domain}} = tracker_script_configuration ->
        cache_content(tracker_script_configuration)

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
end
