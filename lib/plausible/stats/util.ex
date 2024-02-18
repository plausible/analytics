defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @doc """
  `__internal_visits` is fetched when querying bounce rate and visit duration and
  `__internal_pageviews` is additionally fetched when querying views per visit
  as they are needed to calculate these from imported data. This function removes these metrics
  from all entries in the results list.
  """
  def remove_internal_metrics(results, metrics) when is_list(results) do
    has_internal_metrics? =
      Enum.any?(metrics, fn metric ->
        metric in [:bounce_rate, :visit_duration, :views_per_visit]
      end)

    if has_internal_metrics? do
      results
      |> Enum.map(&remove_internal_metrics/1)
    else
      results
    end
  end

  def remove_internal_metrics(result) when is_map(result) do
    Map.drop(result, [:__internal_visits, :__internal_pageviews])
  end
end
