defmodule Plausible.Stats.ScrollDepth do
  @moduledoc """
  Module to check whether the scroll depth metric is available and visible for a site.
  """

  def feature_available?(site, user) do
    FunWithFlags.enabled?(:scroll_depth, for: user) ||
      FunWithFlags.enabled?(:scroll_depth, for: site)
  end

  def feature_visible?(site, user) do
    feature_available?(site, user) && not is_nil(site.scroll_depth_visible_at)
  end
end
