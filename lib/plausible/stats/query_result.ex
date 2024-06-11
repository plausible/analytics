defmodule Plausible.Stats.QueryResult do
  @moduledoc false

  alias Plausible.Stats.Ecto.QueryBuilder
  alias Plausible.Stats.Filters
  alias Plausible.Stats.Query

  @derive Jason.Encoder
  defstruct results: [],
            query: nil,
            meta: %{}

  def from(results, query) do
    results_list =
      results
      |> Enum.map(fn entry ->
        %{
          dimensions: Enum.map(query.dimensions, &Map.get(entry, QueryBuilder.shortname(&1))),
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
      },
      meta: meta(query)
    )
  end

  defp meta(%Query{skip_imported_reason: :unsupported_query}) do
    %{
      warning:
        "Imported stats are not included in the results because query parameters are not supported. " <>
          "For more information, see: https://plausible.io/docs/stats-api#filtering-imported-stats"
    }
  end

  defp meta(_), do: %{}

  defp serializable_filter([operation, "event:goal", clauses]) do
    [operation, "event:goal", Enum.map(clauses, &Filters.Utils.unwrap_goal_value/1)]
  end

  defp serializable_filter(filter), do: filter
end
