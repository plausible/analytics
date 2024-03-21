defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @manually_removable_metrics [
    :__internal_visits,
    :visitors,
    :__total_visitors,
    :__breakdown_value
  ]

  @doc """
  Sometimes we need to manually add metrics in order to calculate the value for
  other metrics. E.g:

  * `__internal_visits` is fetched when querying bounce rate, visit duration,
    or views_per_visit, as it is needed to calculate these from imported data.

  * `visitors` metric might be added manually via `maybe_add_visitors_metric/1`,
    in order to be able to calculate conversion rate.

  This function can be used for stripping those metrics from a breakdown (list),
  or an aggregate (map) result. We do not want to return metrics that we're not
  requested.
  """
  def keep_requested_metrics(results, requested_metrics) when is_list(results) do
    Enum.map(results, fn results_map ->
      keep_requested_metrics(results_map, requested_metrics)
    end)
  end

  def keep_requested_metrics(results, requested_metrics) do
    Map.drop(results, @manually_removable_metrics -- requested_metrics)
  end

  @doc """
  This function adds the `visitors` metric into the list of
  given metrics if it's not already there and if it is needed
  for any of the other metrics to be calculated.
  """
  def maybe_add_visitors_metric(metrics) do
    needed? = Enum.any?([:conversion_rate, :time_on_page], &(&1 in metrics))

    if needed? and :visitors not in metrics do
      metrics ++ [:visitors]
    else
      metrics
    end
  end

  def calculate_cr(nil, _converted_visitors), do: nil

  def calculate_cr(unique_visitors, converted_visitors) do
    if unique_visitors > 0,
      do: Float.round(converted_visitors / unique_visitors * 100, 1),
      else: 0.0
  end
end
