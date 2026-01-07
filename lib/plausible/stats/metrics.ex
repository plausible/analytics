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
                 :exit_rate,
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
  def default_value(:exit_rate, _query, _dimensions), do: nil
  def default_value(:scroll_depth, _query, _dimensions), do: nil
  def default_value(:time_on_page, _query, _dimensions), do: nil

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

  def dashboard_metric_label(:visitors, %{realtime?: true}), do: "Current visitors"
  def dashboard_metric_label(:visitors, %{goal_filter?: true}), do: "Conversions"

  def dashboard_metric_label(:visitors, %{dimensions: ["visit:entry_page"]}),
    do: "Unique entrances"

  def dashboard_metric_label(:visitors, %{dimensions: ["visit:exit_page"]}), do: "Unique exits"
  def dashboard_metric_label(:visitors, _context), do: "Visitors"

  def dashboard_metric_label(:conversion_rate, _context), do: "CR"
  def dashboard_metric_label(:group_conversion_rate, _context), do: "CR"

  def dashboard_metric_label(metric, _context), do: "#{metric}"
end
