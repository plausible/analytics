defmodule Plausible.Stats.QueryOptimizer do
  @moduledoc """
    This module manipulates an existing query, updating it according to business logic.

    For example, it:
    1. Adds a missing order_by clause to a query
    2. Figures out what the right granularity to group by is
  """

  alias Plausible.Stats.Query

  def optimize(query) do
    Enum.reduce(pipeline(), query, fn step, acc -> step.(acc) end)
  end

  defp pipeline() do
    [
      &update_group_by_time/1,
      &add_missing_order_by/1
    ]
  end

  defp add_missing_order_by(%Query{order_by: nil} = query) do
    %Query{query | order_by: missing_order_by(query.metrics, query.dimensions)}
  end

  defp add_missing_order_by(query), do: query

  defp missing_order_by(metrics, [time_dimension | dimensions])
       when time_dimension in ["time:hour", "time:day", "time:month"] do
    [{time_dimension, :asc}] ++ missing_order_by(metrics, dimensions)
  end

  defp missing_order_by([metric | _rest], _dimensions), do: [{metric, :desc}]

  defp update_group_by_time(
         %Query{
           date_range: %Date.Range{first: first, last: last},
           dimensions: ["time" | dimensions]
         } = query
       ) do
    time_dimension =
      cond do
        Timex.diff(last, first, :hours) <= 48 -> "time:hour"
        Timex.diff(last, first, :days) <= 40 -> "time:day"
        true -> "time:month"
      end

    %Query{query | dimensions: [time_dimension | dimensions]}
  end

  defp update_group_by_time(query), do: query
end
