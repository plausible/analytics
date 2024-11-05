defmodule Plausible.Stats.Metrics do
  @moduledoc """
  A module listing all available metrics in Plausible.

  Useful for an explicit string to atom conversion.
  """

  use Plausible

  @all_metrics [
                 :visitors,
                 :visits,
                 :pageviews,
                 :views_per_visit,
                 :bounce_rate,
                 :visit_duration,
                 :events,
                 :conversion_rate,
                 :group_conversion_rate,
                 :time_on_page,
                 :percentage,
                 :scroll_depth
               ] ++ on_ee(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])

  @metric_mappings Enum.into(@all_metrics, %{}, fn metric -> {to_string(metric), metric} end)

  def metric?(value), do: Enum.member?(@all_metrics, value)

  def from_string!(str) do
    Map.fetch!(@metric_mappings, str)
  end

  def from_string(str) do
    Map.fetch(@metric_mappings, str)
  end
end
