defmodule Plausible.Stats.QueryRunner do
  @moduledoc """
  This module is responsible for executing a Plausible.Stats.Query
  and gathering results.

  Some secondary responsibilities are:
  1. Dealing with comparison queries and combining results with main
  2. Dealing with time-on-page
  3. Getting total_rows from ClickHouse results
  """

  use Plausible
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{
    Comparisons,
    Compare,
    Query,
    QueryOptimizer,
    QueryResult,
    Metrics,
    SQL,
    Util,
    Time
  }

  defstruct [
    :site,
    :main_query,
    :main_results,
    :comparison_query,
    :comparison_results,
    :total_rows,
    :results
  ]

  def run(site, query) do
    optimized_query = QueryOptimizer.optimize(query)

    Query.trace(optimized_query, optimized_query.metrics)

    %__MODULE__{main_query: optimized_query, site: site}
    |> execute_main_query()
    |> add_comparison_query()
    |> execute_comparison_query()
    |> build_results_list()
    |> QueryResult.from()
  end

  defp execute_main_query(%__MODULE__{main_query: query, site: site} = runner) do
    ch_results = execute_query(query, site)

    main_results = build_from_ch(ch_results, query)

    runner = struct!(runner, main_results: main_results)

    if query.include.total_rows do
      struct!(runner, total_rows: total_rows(ch_results))
    else
      runner
    end
  end

  defp add_comparison_query(%__MODULE__{main_query: query, main_results: main_results} = runner)
       when not is_nil(query.include.compare) do
    comparison_query =
      query
      |> Comparisons.get_comparison_query()
      |> Comparisons.add_comparison_filters(main_results)
      |> QueryOptimizer.optimize()

    struct!(runner, comparison_query: comparison_query)
  end

  defp add_comparison_query(runner), do: runner

  defp execute_comparison_query(
         %__MODULE__{comparison_query: comparison_query, site: site} = runner
       ) do
    if comparison_query do
      ch_results = execute_query(comparison_query, site)
      comparison_results = build_from_ch(ch_results, comparison_query)

      struct!(runner, comparison_results: comparison_results)
    else
      runner
    end
  end

  # Assembles the final results list, optionally attaching comparison data.
  #
  # Without a comparison, main results are returned as-is.
  #
  # With a comparison, timeseries and non-time-dimension breakdowns are handled
  # separately because they have fundamentally different shapes:
  #
  #   - Non-time breakdowns (e.g. by page, source) return one row per dimension
  #     group. The comparison query is filtered to the same set of dimension
  #     values as the main query, so every comparison result is guaranteed to
  #     have a matching main result. The two lists can be joined by dimension
  #     value in a single pass.
  #
  #   - Timeseries (single "time:*" dimension) return one row per time bucket,
  #     and the comparison period may cover a different number of buckets than
  #     the main period. The two label sequences are zipped together (with nil
  #     padding for whichever side is shorter), producing rows for every bucket
  #     on either side regardless of whether the other side has data.
  defp build_results_list(%__MODULE__{main_query: query, main_results: main_results} = runner) do
    results =
      case {query.include.compare, query.dimensions} do
        {nil, _dimensions} ->
          main_results

        {_non_nil_compare, ["time:" <> _]} ->
          build_timeseries_with_comparison(runner)

        {_non_nil_compare, _dimensions} ->
          merge_with_comparison_results(main_results, runner)
      end

    struct!(runner, results: results)
  end

  defp build_timeseries_with_comparison(%__MODULE__{main_query: query} = runner) do
    main_map = index_by_dimensions(runner.main_results)
    comparison_map = index_by_dimensions(runner.comparison_results)

    main_labels = Time.time_labels(query)
    comp_labels = Time.time_labels(runner.comparison_query)
    n = max(length(main_labels), length(comp_labels))

    pairs =
      Enum.zip(
        main_labels ++ List.duplicate(nil, n - length(main_labels)),
        comp_labels ++ List.duplicate(nil, n - length(comp_labels))
      )

    Enum.map(pairs, fn {main_label, comp_label} ->
      main_metrics =
        if main_label do
          metrics_for_dimension_group(main_map, [main_label], query)
        end

      comparison =
        if comp_label do
          comp_metrics = metrics_for_dimension_group(comparison_map, [comp_label], query)
          change = calculate_metric_changes(query, main_metrics, comp_metrics)

          %{dimensions: [comp_label], metrics: comp_metrics, change: change}
        end

      %{
        dimensions: if(main_label, do: [main_label]),
        metrics: main_metrics,
        comparison: comparison
      }
    end)
  end

  defp execute_query(query, site) do
    query
    |> SQL.QueryBuilder.build(site)
    |> ClickhouseRepo.all(query: query)
  end

  defp build_from_ch(ch_results, query) do
    ch_results
    |> Enum.map(fn entry ->
      dimension_labels = Enum.map(query.dimensions, &dimension_label(&1, entry, query))

      %{
        dimensions: dimension_labels,
        metrics: Enum.map(query.metrics, &get_metric(entry, &1, dimension_labels, query))
      }
    end)
  end

  defp dimension_label("event:goal", entry, query) do
    get_dimension_goal(entry, query)
    |> Plausible.Goal.display_name()
  end

  defp dimension_label("time:" <> _ = time_dimension, entry, query) do
    datetime = Map.get(entry, Util.shortname(query, time_dimension))

    Time.format_datetime(datetime)
  end

  defp dimension_label(dimension, entry, query) do
    Map.get(entry, Util.shortname(query, dimension))
  end

  on_ee do
    defp get_metric(entry, metric, dimensions, query)
         when metric in [:average_revenue, :total_revenue] do
      value = Map.get(entry, metric)

      Plausible.Stats.Goal.Revenue.format_revenue_metric(value, query, dimensions)
    end
  end

  defp get_metric(entry, :events, _dimensions, query) do
    cond do
      "event:goal" in query.dimensions ->
        goal = get_dimension_goal(entry, query)

        if Plausible.Goal.type(goal) != :scroll do
          Map.get(entry, :events)
        else
          nil
        end

      # Cannot show aggregate when there are at least some scroll goal filters
      Plausible.Stats.Goals.toplevel_scroll_goal_filters?(query) ->
        nil

      true ->
        Map.get(entry, :events)
    end
  end

  defp get_metric(entry, metric, _dimensions, _query), do: Map.get(entry, metric)

  defp get_dimension_goal(entry, query) do
    goal_index = Map.get(entry, Util.shortname(query, "event:goal"))

    query.preloaded_goals.matching_toplevel_filters
    |> Enum.at(goal_index - 1)
  end

  defp merge_with_comparison_results(results_list, runner) do
    comparison_map = index_by_dimensions(runner.comparison_results)
    Enum.map(results_list, &add_comparison_results(&1, runner.main_query, comparison_map))
  end

  defp add_comparison_results(row, query, comparison_map) do
    comparison_metrics = metrics_for_dimension_group(comparison_map, row.dimensions, query)

    change =
      Enum.zip([query.metrics, row.metrics, comparison_metrics])
      |> Enum.map(fn {metric, main_value, comp_value} ->
        Compare.calculate_change(metric, comp_value, main_value)
      end)

    Map.merge(row, %{
      comparison: %{
        dimensions: row.dimensions,
        metrics: comparison_metrics,
        change: change
      }
    })
  end

  defp index_by_dimensions(results_list) do
    results_list
    |> Map.new(fn entry -> {entry.dimensions, entry.metrics} end)
  end

  defp metrics_for_dimension_group(lookup_map, dimensions, query) do
    Map.get_lazy(lookup_map, dimensions, fn -> empty_metrics(query, dimensions) end)
  end

  defp empty_metrics(query, dimensions) do
    query.metrics
    |> Enum.map(fn metric -> Metrics.default_value(metric, query, dimensions) end)
  end

  defp calculate_metric_changes(query, main_metrics, comparison_metrics) do
    if main_metrics do
      Enum.zip([query.metrics, main_metrics, comparison_metrics])
      |> Enum.map(fn {metric, main_value, comp_value} ->
        Compare.calculate_change(metric, comp_value, main_value)
      end)
    end
  end

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows
end
