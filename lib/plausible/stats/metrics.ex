defmodule Plausible.Stats.Metrics do
  @moduledoc """
  A module listing all available metrics in Plausible.

  Useful for an explicit string to atom conversion.
  """

  use Plausible
  alias Plausible.Stats.{Query, Filters}

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

  def dashboard_metric_label(metric, %Query{} = query) do
    goal_filter? =
      Filters.filtering_on_dimension?(query, "event:goal",
        max_depth: 0,
        behavioral_filters: :ignore
      )

    dashboard_metric_label(metric, query, goal_filter?)
  end

  defp dashboard_metric_label(
         :visitors,
         %Query{input_date_range: :realtime_30m, dimensions: []},
         true
       ) do
    "Unique conversions (last 30 min)"
  end

  defp dashboard_metric_label(
         :visitors,
         %Query{input_date_range: :realtime_30m, dimensions: []},
         false
       ) do
    "Unique visitors (last 30 min)"
  end

  defp dashboard_metric_label(:visitors, %Query{input_date_range: :realtime}, false) do
    "Current visitors"
  end

  defp dashboard_metric_label(:visitors, %Query{dimensions: []}, true) do
    "Unique conversions"
  end

  defp dashboard_metric_label(:visitors, %Query{dimensions: []}, false) do
    "Unique visitors"
  end

  defp dashboard_metric_label(:visits, %Query{dimensions: []}, false) do
    "Total visits"
  end

  defp dashboard_metric_label(
         :pageviews,
         %Query{input_date_range: :realtime_30m, dimensions: []},
         false
       ) do
    "Pageviews (last 30 min)"
  end

  defp dashboard_metric_label(:pageviews, %Query{dimensions: []}, false) do
    "Total pageviews"
  end

  defp dashboard_metric_label(:views_per_visit, %Query{}, false) do
    "Views per visit"
  end

  defp dashboard_metric_label(:bounce_rate, %Query{}, false) do
    "Bounce rate"
  end

  defp dashboard_metric_label(:visit_duration, %Query{}, false) do
    "Visit duration"
  end

  defp dashboard_metric_label(:scroll_depth, %Query{}, false) do
    "Scroll depth"
  end

  defp dashboard_metric_label(:time_on_page, %Query{}, false) do
    "Time on page"
  end

  defp dashboard_metric_label(:events, %{input_date_range: :realtime_30m, dimensions: []}, true) do
    "Total conversions (last 30 min)"
  end

  defp dashboard_metric_label(:events, %{dimensions: []}, true) do
    "Total conversions"
  end

  defp dashboard_metric_label(:conversion_rate, %{dimensions: []}, true) do
    "Conversion rate"
  end

  defp dashboard_metric_label(metric, _query, _goal_filter?), do: "#{metric}"
end
