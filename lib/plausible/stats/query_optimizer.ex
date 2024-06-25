defmodule Plausible.Stats.QueryOptimizer do
  @moduledoc false

  alias Plausible.Stats.Query

  def optimize(query) do
    Enum.reduce(pipeline(), query, fn step, acc -> step.(acc) end)
  end

  defp pipeline() do
    [
      &add_missing_order_by/1,
      &update_group_by_time/1
    ]
  end

  defp add_missing_order_by(%Query{order_by: nil} = query) do
    %Query{query | order_by: [{hd(query.metrics), :desc}]}
  end

  defp add_missing_order_by(query), do: query

  defp update_group_by_time(%Query{dimensions: ["time" | rest]} = query) do
    %Query{query | dimensions: ["time:month" | rest]}
  end

  defp update_group_by_time(query), do: query
end
