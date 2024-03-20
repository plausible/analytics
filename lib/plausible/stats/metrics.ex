defmodule Plausible.Stats.Metrics do
  @moduledoc """
  A module keeping the context of all available metrics in Plausible.

  Useful for an explicit string to atom conversion.
  """

  @metrics [
    :visitors,
    :visits,
    :pageviews,
    :views_per_visit,
    :bounce_rate,
    :visit_duration,
    :events,
    :conversion_rate,
    :time_on_page
  ]

  @metric_mappings Enum.into(@metrics, %{}, fn metric -> {to_string(metric), metric} end)

  def from_string!(str) do
    Map.fetch!(@metric_mappings, str)
  end
end
