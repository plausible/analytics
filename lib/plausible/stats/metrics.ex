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

  on_ee do
    def default_value(metric, query, dimensions)
        when metric in [:average_revenue, :total_revenue],
        do: Plausible.Stats.Goal.Revenue.format_revenue_metric(nil, query, dimensions)
  end

  def default_value(:visit_duration, _query, _dimensions), do: nil
  def default_value(:scroll_depth, _query, _dimensions), do: nil

  @float_metrics [
    :views_per_visit,
    :bounce_rate,
    :percentage,
    :conversion_rate,
    :group_conversion_rate
  ]
  def default_value(metric, _query, _dimensions) when metric in @float_metrics, do: 0.0
  def default_value(_metric, _query, _dimensions), do: 0

  def from_string!(str) do
    Map.fetch!(@metric_mappings, str)
  end

  def from_string(str) do
    Map.fetch(@metric_mappings, str)
  end
end
