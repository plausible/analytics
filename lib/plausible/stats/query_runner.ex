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

  # Assembles the final results, optionally attaching comparison data.
  #
  # Without a comparison, main results are returned as-is and comparison_results
  # is nil.
  #
  # With comparisons, timeseries and non-time-dimension breakdowns are handled
  # separately because they have fundamentally different shapes:
  #
  #   - Non-time breakdowns (e.g. by page, source) return one row per dimension
  #     group. The comparison query is filtered to the same set of dimension
  #     values as the main query, so every comparison result is guaranteed to
  #     have a matching main result. Comparison data is merged inline into each
  #     result row; comparison_results is nil.
  #
  #   - Timeseries (single "time:*" dimension) keep results and comparison_results
  #     as separate lists of only non-empty rows. Each comparison row carries a
  #     `change` field computed against the positionally-aligned original bucket
  #     (or nil when there is no corresponding original bucket).
  defp build_results_list(%__MODULE__{main_query: query, main_results: main_results} = runner) do
    case {query.include.compare, query.dimensions} do
      {nil, _dimensions} ->
        struct!(runner,
          results: main_results,
          comparison_results: nil
        )

      {_non_nil_compare, ["time:" <> _]} ->
        struct!(runner,
          results: main_results,
          comparison_results: build_comparison_results(runner)
        )

      {_non_nil_compare, _dimensions} ->
        struct!(runner,
          results: merge_with_comparison_results(main_results, runner),
          comparison_results: nil
        )
    end
  end

  defp build_comparison_results(%__MODULE__{main_query: query} = runner) do
    main_map = index_by_dimensions(runner.main_results)

    comp_label_to_main_label =
      Enum.zip(Time.time_labels(runner.comparison_query), Time.time_labels(query))
      |> Map.new()

    Enum.map(runner.comparison_results, fn %{dimensions: [comp_label]} = comp_row ->
      main_label = Map.get(comp_label_to_main_label, comp_label)
      main_metrics = main_label && Map.get(main_map, [main_label])
      change = calculate_metric_changes(query, main_metrics, comp_row.metrics)

      Map.put(comp_row, :change, change)
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
