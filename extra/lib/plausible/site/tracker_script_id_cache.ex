defmodule Plausible.Site.TrackerScriptIdCache do
  @moduledoc """
  Cache for tracker script IDs to avoid excessive database lookups when the
  script API endpoint is bombarded with random IDs.
  """
  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.Tracker

  import Ecto.Query
  use Plausible
  use Plausible.Cache

  @cache_name :tracker_script_id_cache

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_tracker_script_id

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(TrackerScriptConfiguration, :count)
  end

  @impl true
  def base_db_query(), do: Tracker.get_tracker_script_configuration_base_query()

  @impl true
  def get_from_source(id) do
    case Tracker.get_tracker_script_configuration_by_id(id) do
      %TrackerScriptConfiguration{site: %{domain: _domain}} ->
        true

      _ ->
        nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      tracker_script_configuration, acc ->
        [
          {tracker_script_configuration.id, true}
          | acc
        ]
    end)
  end
end
