defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @manually_removable_metrics [:__internal_visits, :visitors, :__total_visitors]

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
  given metrics if it's not already there and if there is a
  `conversion_rate` metric in the list.

  Currently, the conversion rate cannot be queried from the
  database with a simple select clause - instead, we need to
  fetch the database result first, and then manually add it
  into the aggregate map or every entry of thebreakdown list.

  In order for us to be able to calculate it based on the
  results returned by the database query, the visitors metric
  needs to be queried.
  """
  def maybe_add_visitors_metric(metrics) do
    if :conversion_rate in metrics and :visitors not in metrics do
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
