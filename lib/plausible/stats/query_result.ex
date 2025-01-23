defmodule Plausible.Stats.QueryResult do
  @moduledoc """
  This struct contains the (JSON-encodable) response for a query and
  is responsible for building it from database query results.

  For the convenience of API docs and consumers, the JSON result
  produced by Jason.encode(query_result) is ordered.
  """

  use Plausible
  alias Plausible.Stats.{DateTimeRange, Query, QueryRunner}

  defstruct results: [],
            meta: %{},
            query: nil

  @doc """
  Builds full JSON-serializable query response.

  `results` should already-built by Plausible.Stats.QueryRunner
  """
  def from(%QueryRunner{site: site, main_query: query, results: results} = runner) do
    struct!(
      __MODULE__,
      results: results,
      meta: meta(runner),
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

  defp meta(%QueryRunner{} = runner) do
    %{}
    |> add_imports_meta(runner)
    |> add_metric_warnings_meta(runner)
    |> add_time_labels_meta(runner.main_query)
    |> add_total_rows_meta(runner.main_query, runner.total_rows)
  end

  @imports_warnings %{
    unsupported_query:
      "Imported stats are not included in the results because query parameters are not supported. " <>
        "For more information, see: https://plausible.io/docs/stats-api#filtering-imported-stats",
    unsupported_interval:
      "Imported stats are not included because the time dimension (i.e. the interval) is too short."
  }

  defp add_imports_meta(meta, %QueryRunner{} = runner) do
    %{main_query: %{include: include} = main_query} = runner

    if include.imports or include[:imports_meta] do
      comparison_query = Map.get(runner, :comparison_query)

      imports_included =
        case comparison_query do
          %Query{include_imported: true} -> true
          _ -> main_query.include_imported
        end

      imports_skip_reason =
        case comparison_query do
          %Query{skip_imported_reason: nil} -> nil
          _ -> main_query.skip_imported_reason
        end

      imports_warning =
        if imports_skip_reason in Map.keys(@imports_warnings) do
          @imports_warnings[imports_skip_reason]
        end

      %{
        imports_included: imports_included,
        imports_skip_reason: imports_skip_reason,
        imports_warning: imports_warning
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.merge(meta)
    else
      meta
    end
  end

  defp add_metric_warnings_meta(meta, %QueryRunner{main_query: query}) do
    warnings = metric_warnings(query)

    if map_size(warnings) > 0 do
      Map.put(meta, :metric_warnings, warnings)
    else
      meta
    end
  end

  defp add_time_labels_meta(meta, query) do
    if query.include.time_labels do
      Map.put(meta, :time_labels, Plausible.Stats.Time.time_labels(query))
    else
      meta
    end
  end

  defp add_total_rows_meta(meta, query, total_rows) do
    if query.include.total_rows do
      Map.put(meta, :total_rows, total_rows)
    else
      meta
    end
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

  defp metric_warnings(query) do
    Enum.reduce(query.metrics, %{}, fn metric, acc ->
      case metric_warning(metric, query) do
        nil -> acc
        %{} = warning -> Map.put(acc, metric, warning)
      end
    end)
  end

  on_ee do
    @revenue_metrics Plausible.Stats.Goal.Revenue.revenue_metrics()

    @revenue_metrics_warnings %{
      revenue_goals_unavailable:
        "The owner of this site does not have access to the revenue metrics feature.",
      no_single_revenue_currency:
        "Revenue metrics are null as there are multiple currencies for the selected event:goals.",
      no_revenue_goals_matching:
        "Revenue metrics are null as there are no matching revenue goals."
    }

    defp metric_warning(metric, query) when metric in @revenue_metrics do
      if query.revenue_warning do
        %{
          code: query.revenue_warning,
          warning: @revenue_metrics_warnings[query.revenue_warning]
        }
      else
        nil
      end
    end
  end

  defp metric_warning(_metric, _query), do: nil

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
