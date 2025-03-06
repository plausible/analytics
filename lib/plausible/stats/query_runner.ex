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
    QueryOptimizer,
    QueryResult,
    Legacy,
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

    %__MODULE__{main_query: optimized_query, site: site}
    |> execute_main_query()
    |> add_comparison_query()
    |> execute_comparison_query()
    |> build_results_list()
    |> QueryResult.from()
  end

  defp execute_main_query(%__MODULE__{main_query: query, site: site} = runner) do
    {ch_results, time_on_page} = execute_query(query, site)

    main_results = build_from_ch(ch_results, query, time_on_page)

    runner = struct!(runner, main_results: main_results)

    if query.include.total_rows do
      struct!(runner, total_rows: total_rows(ch_results))
    else
      runner
    end
  end

  defp add_comparison_query(%__MODULE__{main_query: query, main_results: main_results} = runner)
       when is_map(query.include.comparisons) do
    comparison_query =
      query
      |> Comparisons.get_comparison_query()
      |> Comparisons.add_comparison_filters(main_results)

    struct!(runner, comparison_query: comparison_query)
  end

  defp add_comparison_query(runner), do: runner

  defp execute_comparison_query(
         %__MODULE__{comparison_query: comparison_query, site: site} = runner
       ) do
    if comparison_query do
      {ch_results, time_on_page} = execute_query(comparison_query, site)

      comparison_results =
        build_from_ch(
          ch_results,
          comparison_query,
          time_on_page
        )

      struct!(runner, comparison_results: comparison_results)
    else
      runner
    end
  end

  defp get_time_lookup(query, comparison_query) do
    if Time.time_dimension(query) && comparison_query do
      Enum.zip(
        Time.time_labels(query),
        Time.time_labels(comparison_query)
      )
      |> Map.new()
    else
      %{}
    end
  end

  defp build_results_list(%__MODULE__{main_query: query, main_results: main_results} = runner) do
    results =
      case query.dimensions do
        ["time:" <> _] -> main_results |> add_empty_timeseries_rows(runner)
        _ -> main_results
      end
      |> merge_with_comparison_results(runner)

    struct!(runner, results: results)
  end

  defp execute_query(query, site) do
    ch_results =
      query
      |> SQL.QueryBuilder.build(site)
      |> ClickhouseRepo.all(query: query)

    time_on_page = Legacy.TimeOnPage.calculate(site, query, ch_results)

    {ch_results, time_on_page}
  end

  defp build_from_ch(ch_results, query, time_on_page) do
    ch_results
    |> Enum.map(fn entry ->
      dimension_labels = Enum.map(query.dimensions, &dimension_label(&1, entry, query))

      %{
        dimensions: dimension_labels,
        metrics:
          Enum.map(query.metrics, &get_metric(entry, &1, dimension_labels, query, time_on_page))
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
    defp get_metric(entry, metric, dimensions, query, _time_on_page)
         when metric in [:average_revenue, :total_revenue] do
      value = Map.get(entry, metric)

      Plausible.Stats.Goal.Revenue.format_revenue_metric(value, query, dimensions)
    end
  end

  defp get_metric(_entry, :time_on_page, dimensions, _query, time_on_page),
    do: Map.get(time_on_page, dimensions)

  defp get_metric(entry, :events, _dimensions, query, _time_on_page) do
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

  defp get_metric(entry, metric, _dimensions, _query, _time_on_page), do: Map.get(entry, metric)

  defp get_dimension_goal(entry, query) do
    goal_index = Map.get(entry, Util.shortname(query, "event:goal"))

    query.preloaded_goals.matching_toplevel_filters
    |> Enum.at(goal_index - 1)
  end

  # Special case: If comparison and single time dimension, add 0 rows - otherwise
  # comparisons would not be shown for timeseries with 0 values.
  defp add_empty_timeseries_rows(results_list, %__MODULE__{main_query: query})
       when is_map(query.include.comparisons) do
    indexed_results = index_by_dimensions(results_list)

    empty_timeseries_rows =
      Time.time_labels(query)
      |> Enum.reject(fn dimension_value -> Map.has_key?(indexed_results, [dimension_value]) end)
      |> Enum.map(fn dimension_value ->
        %{
          metrics: empty_metrics(query, [dimension_value]),
          dimensions: [dimension_value]
        }
      end)

    results_list ++ empty_timeseries_rows
  end

  defp add_empty_timeseries_rows(results_list, _), do: results_list

  defp merge_with_comparison_results(results_list, runner) do
    comparison_map = (runner.comparison_results || []) |> index_by_dimensions()
    time_lookup = get_time_lookup(runner.main_query, runner.comparison_query)

    Enum.map(
      results_list,
      &add_comparison_results(&1, runner.main_query, comparison_map, time_lookup)
    )
  end

  defp add_comparison_results(row, query, comparison_map, time_lookup)
       when is_map(query.include.comparisons) do
    dimensions = get_comparison_dimensions(row.dimensions, query, time_lookup)
    comparison_metrics = get_comparison_metrics(comparison_map, dimensions, query)

    change =
      Enum.zip([query.metrics, row.metrics, comparison_metrics])
      |> Enum.map(fn {metric, metric_value, comparison_value} ->
        Compare.calculate_change(metric, comparison_value, metric_value)
      end)

    Map.merge(row, %{
      comparison: %{
        dimensions: dimensions,
        metrics: comparison_metrics,
        change: change
      }
    })
  end

  defp add_comparison_results(row, _, _, _), do: row

  defp get_comparison_dimensions(dimensions, query, time_lookup) do
    query.dimensions
    |> Enum.zip(dimensions)
    |> Enum.map(fn
      {"time:" <> _, value} -> time_lookup[value]
      {_, value} -> value
    end)
  end

  defp index_by_dimensions(results_list) do
    results_list
    |> Map.new(fn entry -> {entry.dimensions, entry.metrics} end)
  end

  defp get_comparison_metrics(comparison_map, dimensions, query) do
    Map.get_lazy(comparison_map, dimensions, fn -> empty_metrics(query, dimensions) end)
  end

  defp empty_metrics(query, dimensions) do
    query.metrics
    |> Enum.map(fn metric -> Metrics.default_value(metric, query, dimensions) end)
  end

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows
end
