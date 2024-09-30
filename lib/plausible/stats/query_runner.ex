defmodule Plausible.Stats.QueryRunner do
  @doc """
  This module is responsible for executing a Plausible.Stats.Query
  and gathering results.

  Some secondary responsibilities are:
  1. Dealing with comparison queries and combining results with main
  2. Dealing with time-on-page
  3. Passing total_rows from clickhouse to QueryResult meta
  """

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

  def run(site, query) do
    optimized_query = QueryOptimizer.optimize(query)

    assigns =
      %{query: optimized_query, site: site}
      |> add_comparison_query()
      |> execute_comparison()
      |> add_comparison_map()
      |> execute_main_query()
      |> add_meta_extra()
      |> add_results_list()

    QueryResult.from(assigns.query_result, site, optimized_query, assigns.meta_extra)
  end

  defp add_comparison_query(%{query: query} = assigns) when query.include.comparisons do
    comparison_query = Comparisons.compare(query, query.include.comparisons)
    Map.put(assigns, :comparison_query, comparison_query)
  end

  defp add_comparison_query(assigns), do: assigns

  defp execute_comparison(%{comparison_query: comparison_query, site: site}) do
    {ch_results, time_on_page} = execute_query(comparison_query, site)

    comparison_results =
      build_results_list(
        ch_results,
        comparison_query,
        time_on_page,
        %{}
      )

    Map.put(assigns, :comparison_results, comparison_results)
  end

  defp execute_comparison(assigns), do: assigns

  defp add_comparison_map(
         %{
           comparison_query: comparison_query,
           comparison_results: comparison_results,
           query: query
         } = assigns
       ) do
    time_dimension = query.dimensions |> Time.time_dimension()

    time_lookup =
      if time_dimension do
        Enum.zip(
          Time.time_labels(comparison_query),
          Time.time_labels(query)
        )
        |> Map.new()
      else
        %{}
      end

    comparison_map =
      comparison_results
      |> Map.new(fn entry ->
        dimensions_key =
          entry.dimensions
          |> Enum.zip(query.dimensions)
          |> Enum.map(fn {dimension_value, dimension} ->
            # If dealing with time series, look up comparison in main path
            if dimension == time_dimension do
              Map.get(time_lookup, dimension_value, dimension_value)
            else
              dimension_value
            end
          end)

        {dimensions_key, entry.metrics}
      end)

    Map.put(assigns, :comparison_map, comparison_map)
  end

  defp add_comparison_map(assigns), do: assigns

  defp execute_main_query(assigns) do
    {ch_results, time_on_page} = execute_query(assigns.query, site)

    Map.merge(assigns, %{
      ch_results: ch_results,
      time_on_page: time_on_page
    })
  end

  defp add_meta_extra(%{query: query, ch_results: ch_results} = assigns) do
    Map.put(assigns, :meta_extra, %{
      total_rows: if(query.include.total_rows, do: total_rows(ch_results), else: nil)
    })
  end

  defp add_results_list(assigns) do
    results_list =
      build_results_list(
        assigns.ch_results,
        assigns.query,
        assigns.time_on_page,
        assigns
      )

    Map.put(assigns, :results_list, results_list)
  end

  defp execute_query(query, site) do
    ch_results =
      query
      |> SQL.QueryBuilder.build(site)
      |> ClickhouseRepo.all(query: query)

    time_on_page = Legacy.TimeOnPage.calculate(site, query, ch_results)

    {ch_results, time_on_page}
  end

  defp build_results_list(ch_results, query, time_on_page, assigns) do
    comparison_map = Map.get(assigns, :comparison_map, %{})

    results_list =
      ch_results
      |> Enum.map(fn entry ->
        dimensions = Enum.map(query.dimensions, &dimension_label(&1, entry, query))

        %{
          dimensions: dimensions,
          metrics: Enum.map(query.metrics, &get_metric(entry, &1, dimensions, time_on_page))
        }
        |> add_comparison_results(comparison_map, query)
      end)

    results_list
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

  defp get_metric(_entry, :time_on_page, dimensions, time_on_page),
    do: Map.get(time_on_page, dimensions)

  defp get_metric(entry, metric, _dimensions, _time_on_page), do: Map.get(entry, metric)

  defp add_comparison_results(row, comparison_map, query) when query.include.comparisons do
    comparison_metrics = get_comparison_metrics(comparison_map, row.dimensions, query)

    change =
      Enum.zip([query.metrics, row.metrics, comparison_metrics])
      |> Enum.map(fn {metric, metric_value, comparison_value} ->
        Compare.calculate_change(metric, comparison_value, metric_value)
      end)

    Map.merge(row, %{
      comparison: %{
        metrics: comparison_metrics,
        change: change
      }
    })
  end

  defp add_comparison_results(row, _comparison_row, _query), do: row

  defp get_comparison_metrics(comparison_map, dimensions, query) do
    Map.get_lazy(comparison_map, dimensions, fn -> List.duplicate(0, length(query.metrics)) end)
  end

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows
end
