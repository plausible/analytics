defmodule Plausible.Stats.QueryResult do
  @moduledoc """
  This struct contains the (JSON-encodable) response for a query and
  is responsible for building it from database query results.

  For the convenience of API docs and consumers, the JSON result
  produced by Jason.encode(query_result) is ordered.
  """

  use Plausible
  alias Plausible.Stats.DateTimeRange

  defstruct results: [],
            meta: %{},
            query: nil

  @doc """
  Builds full JSON-serializable query response.

  `results` should already-built by Plausible.Stats.QueryRunner
  """
  def from(results, site, query, meta_extra) do
    struct!(
      __MODULE__,
      results: results,
      meta: meta(query, meta_extra),
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
          include: include(query) |> Map.filter(fn {_key, val} -> val end),
          pagination: query.pagination
        )
    )
  end

  @imports_warnings %{
    unsupported_query:
      "Imported stats are not included in the results because query parameters are not supported. " <>
        "For more information, see: https://plausible.io/docs/stats-api#filtering-imported-stats",
    unsupported_interval:
      "Imported stats are not included because the time dimension (i.e. the interval) is too short."
  }

  defp meta(query, meta_extra) do
    %{
      imports_included: if(query.include.imports, do: query.include_imported, else: nil),
      imports_skip_reason:
        if(query.include.imports and query.skip_imported_reason,
          do: to_string(query.skip_imported_reason)
        ),
      imports_warning: @imports_warnings[query.skip_imported_reason],
      metric_warnings: metric_warnings(query),
      time_labels:
        if(query.include.time_labels, do: Plausible.Stats.Time.time_labels(query), else: nil),
      total_rows: if(query.include.total_rows, do: meta_extra.total_rows, else: nil)
    }
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp include(query) do
    case get_in(query.include, [:comparisons, :date_range]) do
      %DateTimeRange{first: first, last: last} ->
        query.include
        |> put_in([:comparisons, :date_range], [
          to_iso8601(first, query.timezone),
          to_iso8601(last, query.timezone)
        ])

      nil ->
        query.include
    end
  end

  on_ee do
    @revenue_metrics_warnings %{
      revenue_goals_unavailable:
        "The owner of this site does not have access to the revenue metrics feature.",
      no_single_revenue_currency:
        "Revenue metrics are null as there are multiple currencies for the selected event:goals.",
      no_revenue_goals_matching:
        "Revenue metrics are null as there are no matching revenue goals."
    }

    defp metric_warnings(query) do
      if query.revenue_warning do
        query.metrics
        |> Enum.filter(&(&1 in Plausible.Stats.Goal.Revenue.revenue_metrics()))
        |> Enum.map(
          &{&1,
           %{
             code: query.revenue_warning,
             warning: @revenue_metrics_warnings[query.revenue_warning]
           }}
        )
        |> Map.new()
      else
        nil
      end
    end
  else
    defp metric_warnings(_query), do: nil
  end

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
