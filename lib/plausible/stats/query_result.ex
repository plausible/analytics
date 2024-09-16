defmodule Plausible.Stats.QueryResult do
  @moduledoc """
  This struct contains the (JSON-encodable) response for a query and
  is responsible for building it from database query results.

  For the convenience of API docs and consumers, the JSON result
  produced by Jason.encode(query_result) is ordered.
  """

  alias Plausible.Stats.{Util, Filters}

  defstruct results: [],
            meta: %{},
            query: nil

  def from(results, site, query) do
    results_list =
      results
      |> Enum.map(fn entry ->
        %{
          dimensions: Enum.map(query.dimensions, &dimension_label(&1, entry, query)),
          metrics: Enum.map(query.metrics, &Map.get(entry, &1))
        }
      end)

    struct!(
      __MODULE__,
      results: results_list,
      meta: meta(query, results),
      query:
        Jason.OrderedObject.new(
          site_id: site.domain,
          metrics: query.metrics,
          date_range: [
            to_iso8601(query.utc_time_range.first, query.timezone),
            to_iso8601(query.utc_time_range.last, query.timezone)
          ],
          filters: query.filters,
          dimensions: query.dimensions,
          order_by: query.order_by |> Enum.map(&Tuple.to_list/1),
          include: query.include |> Map.filter(fn {_key, val} -> val end),
          pagination: query.pagination
        )
    )
  end

  defp dimension_label("event:goal", entry, query) do
    {events, paths} = Filters.Utils.split_goals(query.preloaded_goals)

    goal_index = Map.get(entry, Util.shortname(query, "event:goal"))

    # Closely coupled logic with Plausible.Stats.SQL.Expression.event_goal_join/2
    cond do
      goal_index < 0 -> Enum.at(events, -goal_index - 1) |> Plausible.Goal.display_name()
      goal_index > 0 -> Enum.at(paths, goal_index - 1) |> Plausible.Goal.display_name()
    end
  end

  defp dimension_label("time:" <> _ = time_dimension, entry, query) do
    datetime = Map.get(entry, Util.shortname(query, time_dimension))

    Plausible.Stats.Time.format_datetime(datetime)
  end

  defp dimension_label(dimension, entry, query) do
    Map.get(entry, Util.shortname(query, dimension))
  end

  @imports_unsupported_query_warning "Imported stats are not included in the results because query parameters are not supported. " <>
                                       "For more information, see: https://plausible.io/docs/stats-api#filtering-imported-stats"

  @imports_unsupported_interval_warning "Imported stats are not included because the time dimension (i.e. the interval) is too short."

  defp meta(query, results) do
    %{
      imports_included: if(query.include.imports, do: query.include_imported, else: nil),
      imports_skip_reason:
        if(query.include.imports and query.skip_imported_reason,
          do: to_string(query.skip_imported_reason)
        ),
      imports_warning:
        case query.skip_imported_reason do
          :unsupported_query -> @imports_unsupported_query_warning
          :unsupported_interval -> @imports_unsupported_interval_warning
          _ -> nil
        end,
      time_labels:
        if(query.include.time_labels, do: Plausible.Stats.Time.time_labels(query), else: nil),
      total_rows: if(query.include.total_rows, do: total_rows(results), else: nil)
    }
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows

  defp to_iso8601(datetime, timezone) do
    datetime
    |> DateTime.shift_zone!(timezone)
    |> DateTime.to_iso8601(:extended)
  end
end

defimpl Jason.Encoder, for: Plausible.Stats.QueryResult do
  def encode(%Plausible.Stats.QueryResult{results: results, meta: meta, query: query}, opts) do
    Jason.OrderedObject.new(results: results, meta: meta, query: query)
    |> Jason.Encoder.encode(opts)
  end
end
