defmodule Plausible.Stats.QueryRunner do
  @moduledoc """
  This module is responsible for executing a Plausible.Stats.Query
  and gathering results.

  Some secondary responsibilities are:
  1. Dealing with comparison queries and combining results with main
  2. Dealing with time-on-page
  3. Passing total_rows from clickhouse to QueryResult meta
  """

  use Plausible
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{
    Comparisons,
    Compare,
    QueryOptimizer,
    QueryResult,
    Legacy,
    Filters,
    SQL,
    Util,
    Time
  }

  defstruct [
    :query,
    :site,
    :comparison_query,
    :comparison_results,
    :main_results_list,
    :ch_results,
    :meta_extra,
    :time_lookup,
    :results_list
  ]

  def run(site, query) do
    optimized_query = QueryOptimizer.optimize(query)

    run_results =
      %__MODULE__{query: optimized_query, site: site}
      |> execute_main_query()
      |> add_comparison_query()
      |> execute_comparison()
      |> add_meta_extra()
      |> add_time_lookup()
      |> build_results_list()

    QueryResult.from(run_results.results_list, site, optimized_query, run_results.meta_extra)
  end

  defp execute_main_query(%__MODULE__{query: query, site: site} = run_results) do
    {ch_results, time_on_page} = execute_query(query, site)

    struct!(
      run_results,
      main_results_list: build_from_ch(ch_results, query, time_on_page),
      ch_results: ch_results
    )
  end

  defp add_comparison_query(
         %__MODULE__{query: query, main_results_list: main_results_list} = run_results
       )
       when is_map(query.include.comparisons) do
    comparison_query =
      query
      |> Comparisons.get_comparison_query(query.include.comparisons)
      |> Comparisons.add_comparison_filters(main_results_list)

    struct!(run_results, comparison_query: comparison_query)
  end

  defp add_comparison_query(run_results), do: run_results

  defp execute_comparison(
         %__MODULE__{comparison_query: comparison_query, site: site} = run_results
       ) do
    if comparison_query do
      {ch_results, time_on_page} = execute_query(comparison_query, site)

      comparison_results =
        build_from_ch(
          ch_results,
          comparison_query,
          time_on_page
        )

      struct!(run_results, comparison_results: comparison_results)
    else
      run_results
    end
  end

  defp add_time_lookup(run_results) do
    time_lookup =
      if Time.time_dimension(run_results.query) && run_results.comparison_query do
        Enum.zip(
          Time.time_labels(run_results.query),
          Time.time_labels(run_results.comparison_query)
        )
        |> Map.new()
      else
        %{}
      end

    struct!(run_results, time_lookup: time_lookup)
  end

  defp add_meta_extra(%__MODULE__{query: query, ch_results: ch_results} = run_results) do
    struct!(run_results,
      meta_extra: %{
        total_rows: if(query.include.total_rows, do: total_rows(ch_results), else: nil)
      }
    )
  end

  defp build_results_list(
         %__MODULE__{query: query, main_results_list: main_results_list} = run_results
       ) do
    results_list =
      case query.dimensions do
        ["time:" <> _] -> main_results_list |> add_empty_timeseries_rows(run_results)
        _ -> main_results_list
      end
      |> merge_with_comparison_results(run_results)

    struct!(run_results, results_list: results_list)
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
      dimensions = Enum.map(query.dimensions, &dimension_label(&1, entry, query))

      %{
        dimensions: dimensions,
        metrics: Enum.map(query.metrics, &get_metric(entry, &1, dimensions, query, time_on_page))
      }
    end)
  end

  defp dimension_label("event:goal", entry, query) do
    {events, paths} = Filters.Utils.split_goals(query.preloaded_goals)

    goal_index = Map.get(entry, Util.shortname(query, "event:goal"))

    # Closely coupled logic with SQL.Expression.event_goal_join/2
    cond do
      goal_index < 0 -> Enum.at(events, -goal_index - 1) |> Plausible.Goal.display_name()
      goal_index > 0 -> Enum.at(paths, goal_index - 1) |> Plausible.Goal.display_name()
    end
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

      if query.include[:format_revenue_metrics] do
        Plausible.Stats.Goal.Revenue.format_revenue_metric(value, query, dimensions)
      else
        value
      end
    end
  end

  defp get_metric(_entry, :time_on_page, dimensions, _query, time_on_page),
    do: Map.get(time_on_page, dimensions)

  defp get_metric(entry, metric, _dimensions, _query, _time_on_page), do: Map.get(entry, metric)

  # Special case: If comparison and single time dimension, add 0 rows - otherwise
  # comparisons would not be shown for timeseries with 0 values.
  defp add_empty_timeseries_rows(results_list, %__MODULE__{query: query})
       when is_map(query.include.comparisons) do
    indexed_results = index_by_dimensions(results_list)

    empty_timeseries_rows =
      Time.time_labels(query)
      |> Enum.reject(fn dimension_value -> Map.has_key?(indexed_results, [dimension_value]) end)
      |> Enum.map(fn dimension_value ->
        %{
          metrics: empty_metrics(query),
          dimensions: [dimension_value]
        }
      end)

    results_list ++ empty_timeseries_rows
  end

  defp add_empty_timeseries_rows(results_list, _), do: results_list

  defp merge_with_comparison_results(results_list, run_results) do
    comparison_map = (run_results.comparison_results || []) |> index_by_dimensions()
    time_lookup = run_results.time_lookup || %{}

    Enum.map(
      results_list,
      &add_comparison_results(&1, run_results.query, comparison_map, time_lookup)
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
    Map.get_lazy(comparison_map, dimensions, fn -> empty_metrics(query) end)
  end

  defp empty_metrics(query) do
    query.metrics
    |> Enum.map(fn metric -> empty_metric_value(metric) end)
  end

  on_ee do
    defp empty_metric_value(metric)
         when metric in [:total_revenue, :average_revenue],
         do: nil
  end

  defp empty_metric_value(_), do: 0

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows
end
