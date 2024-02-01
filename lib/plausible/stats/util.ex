defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @doc """
  `__internal_visits` is fetched when querying bounce rate and visit duration, as it
  is needed to calculate these from imported data. This function removes that metric
  from all entries in the results list.
  """
  def remove_internal_visits_metric(results, metrics) when is_list(results) do
    if :bounce_rate in metrics or :visit_duration in metrics do
      results
      |> Enum.map(&remove_internal_visits_metric/1)
    else
      results
    end
  end

  def remove_internal_visits_metric(result) when is_map(result) do
    Map.delete(result, :__internal_visits)
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

  Before returning those results to the client though, we
  probably want to remove the visitors metric from the result
  since it was not really asked for. For that, we can use the
  `maybe_remove_visitors_metric/1` function
  """
  def maybe_add_visitors_metric(metrics) do
    if :conversion_rate in metrics and :visitors not in metrics do
      metrics ++ [:visitors]
    else
      metrics
    end
  end

  @doc """
  This function removes the manually added `visitors` metric
  from the results returned by the db query (either aggregate
  map or breakdown list). See `maybe_add_visitors_metric/1`
  for more information.
  """
  def maybe_remove_visitors_metric(results, asked_metrics) when is_list(results) do
    if :visitors not in asked_metrics do
      Enum.map(results, &Map.delete(&1, :visitors))
    else
      results
    end
  end

  def maybe_remove_visitors_metric(results, asked_metrics) when is_map(results) do
    if :visitors not in asked_metrics do
      Map.delete(results, :visitors)
    else
      results
    end
  end

  def calculate_cr(nil, _converted_visitors), do: nil

  def calculate_cr(unique_visitors, converted_visitors) do
    if unique_visitors > 0,
      do: Float.round(converted_visitors / unique_visitors * 100, 1),
      else: 0.0
  end
end
