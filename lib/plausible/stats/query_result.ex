defmodule Plausible.Stats.QueryResult do
  @moduledoc false

  alias Plausible.Stats.Filters

  @derive Jason.Encoder
  defstruct results: [],
            query: nil

  def from(results, query) do
    results_list =
      results
      |> Enum.map(fn entry ->
        %{
          dimensions: Enum.map(query.dimensions, &Map.get(entry, String.to_atom(&1))),
          metrics: Enum.map(query.metrics, &Map.get(entry, &1))
        }
      end)

    struct!(
      __MODULE__,
      results: results_list,
      query: %{
        metrics: query.metrics,
        date_range: [query.date_range.first, query.date_range.last],
        filters: query.filters |> Enum.map(&serializable_filter/1),
        dimensions: query.dimensions,
        order_by: query.order_by |> Enum.map(&Tuple.to_list/1)
      }
    )
  end

  defp serializable_filter([operation, "event:goal", clauses]) do
    [operation, "event:goal", Enum.map(clauses, &Filters.Utils.unwrap_goal_value/1)]
  end

  defp serializable_filter(filter), do: filter
end
