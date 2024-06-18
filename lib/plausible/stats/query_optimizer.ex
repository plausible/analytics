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
      &add_missing_order_by/1,
      &update_time_in_order_by/1
    ]
  end

  defp add_missing_order_by(%Query{order_by: nil} = query) do
    order_by =
      case time_dimension(query) do
        nil -> [{hd(query.metrics), :desc}]
        time_dimension -> [{time_dimension, :asc}, {hd(query.metrics), :desc}]
      end

    %Query{query | order_by: order_by}
  end

  defp add_missing_order_by(query), do: query

  defp update_group_by_time(
         %Query{
           date_range: %Date.Range{first: first, last: last}
         } = query
       ) do
    dimensions =
      query.dimensions
      |> Enum.map(fn
        "time" -> resolve_time_dimension(first, last)
        entry -> entry
      end)

    %Query{query | dimensions: dimensions}
  end

  defp update_group_by_time(query), do: query

  defp resolve_time_dimension(first, last) do
    cond do
      Timex.diff(last, first, :hours) <= 48 -> "time:hour"
      Timex.diff(last, first, :days) <= 40 -> "time:day"
      true -> "time:month"
    end
  end

  defp update_time_in_order_by(query) do
    order_by =
      query.order_by
      |> Enum.map(fn
        {"time", direction} -> {time_dimension(query), direction}
        entry -> entry
      end)

    %Query{query | order_by: order_by}
  end

  defp time_dimension(query) do
    Enum.find(query.dimensions, &String.starts_with?(&1, "time"))
  end
end
