defmodule Plausible.Stats.Metrics do
  @moduledoc """
  A module listing all available metrics in Plausible.

  Useful for an explicit string to atom conversion.
  """

  use Plausible

  @revenue_metrics on_ee(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])

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
               ] ++ @revenue_metrics

  @metric_mappings Enum.into(@all_metrics, %{}, fn metric -> {to_string(metric), metric} end)

  def metric?(value), do: Enum.member?(@all_metrics, value)

  on_ee do
    # Default value in a goal breakdown depends on per-row currency
    def default_value(metric, query, row_dimensions) when metric in @revenue_metrics do
      Plausible.Stats.Goal.Revenue.format_revenue_metric(nil, query, row_dimensions)
    end
  end

  def default_value(metric, _query, _dimensions), do: default_value(metric)

  on_ee do
    # When revenue metrics are queried without event:goal dimension,
    # a single default currency is expected.
    def default_value(metric, query) when metric in @revenue_metrics do
      currency = query.revenue_currencies.default
      Plausible.Stats.Goal.Revenue.format_revenue_metric(nil, currency)
    end
  end

  def default_value(metric, _query), do: default_value(metric)

  def default_value(:visit_duration), do: nil
  def default_value(:exit_rate), do: nil
  def default_value(:scroll_depth), do: nil
  def default_value(:time_on_page), do: nil

  @float_metrics [
    :views_per_visit,
    :bounce_rate,
    :percentage,
    :conversion_rate,
    :group_conversion_rate
  ]
  def default_value(metric) when metric in @float_metrics, do: 0.0
  def default_value(_metric), do: 0

  def from_string!(str) do
    Map.fetch!(@metric_mappings, str)
  end

  def from_string(str) do
    Map.fetch(@metric_mappings, str)
  end
end
