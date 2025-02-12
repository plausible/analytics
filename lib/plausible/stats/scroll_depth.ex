defmodule Plausible.Stats.ScrollDepth do
  @moduledoc """
  Module to check whether the scroll depth metric is available and visible for a site.
  """

  import Ecto.Query
  require Logger

  alias Plausible.ClickhouseRepo

  def feature_available?(site, user) do
    FunWithFlags.enabled?(:scroll_depth, for: user) ||
      FunWithFlags.enabled?(:scroll_depth, for: site)
  end

  def feature_visible?(site, user) do
    feature_available?(site, user) && not is_nil(site.scroll_depth_visible_at)
  end

  @doc """
  Checks whether the scroll depth feature is visible for a site and updates the site record if it is.

  Note this function queries ClickHouse and may take a while to complete.
  """
  def check_feature_visible!(site, user) do
    cond do
      not feature_available?(site, user) ->
        false

      not is_nil(site.scroll_depth_visible_at) ->
        true

      is_nil(site.scroll_depth_visible_at) ->
        visible? = has_scroll_data_last_30d?(site)

        if visible? do
          Plausible.Sites.set_scroll_depth_visible_at(site)
        end

        visible?
    end
  end

  defp has_scroll_data_last_30d?(site) do
    try do
      ClickhouseRepo.exists?(
        from(e in "events_v2",
          where:
            e.site_id == ^site.id and
              e.name == "engagement" and
              e.timestamp >= fragment("toStartOfDay(now() - toIntervalDay(30))") and
              e.scroll_depth > 0 and e.scroll_depth <= 100
        )
      )
    rescue
      # Avoid propagating error to the user, bringing down the site.
      error ->
        Logger.error("Error checking scroll data for site #{site.id}: #{inspect(error)}")

        false
    end
  end
end
