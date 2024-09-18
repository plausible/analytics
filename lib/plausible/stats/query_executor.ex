defmodule Plausible.Stats.QueryExecutor do
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{QueryOptimizer, Filters, SQL, Util}

  def execute(site, query) do
    optimized_query = QueryOptimizer.optimize(query)

    {comparison_results, _} =
      if optimized_query.include.comparisons do
        {:ok, comparison_query} =
          Plausible.Stats.Comparisons.compare(site, optimized_query, "previous_period")

        execute_and_build_results(comparison_query, site)
      else
        {nil, nil}
      end

    {results_list, meta_extra} =
      execute_and_build_results(optimized_query, site, comparison_results)

    Plausible.Stats.QueryResult.from(results_list, site, optimized_query, meta_extra)
  end

  defp execute_and_build_results(query, site, comparison_results \\ nil) do
    ch_results =
      query
      |> SQL.QueryBuilder.build(site)
      |> ClickhouseRepo.all(query: query)

    time_on_page = Plausible.Stats.Legacy.TimeOnPage.calculate(site, query, ch_results)

    build_results_list(ch_results, time_on_page, comparison_results, query)
  end

  defp build_results_list(ch_results, time_on_page, comparison_results, query) do
    comparison_map =
      if comparison_results do
        comparison_results
        |> Map.new(fn row -> {row.dimensions, row.metrics} end)
      else
        %{}
      end

    results_list =
      ch_results
      |> Enum.map(fn entry ->
        dimensions = Enum.map(query.dimensions, &dimension_label(&1, entry, query))

        %{
          dimensions: dimensions,
          metrics: Enum.map(query.metrics, &get_metric(entry, &1, dimensions, time_on_page))
        }
        |> add_comparison_results(comparison_map, query, not is_nil(query.include.comparisons))
      end)

    {results_list, extra_meta(query, ch_results)}
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

  defp get_metric(_entry, :time_on_page, dimensions, time_on_page),
    do: Map.get(time_on_page, dimensions)

  defp get_metric(entry, metric, _dimensions, _time_on_page), do: Map.get(entry, metric)

  defp add_comparison_results(row, _comparison_row, _query, false = _include_comparisons), do: row

  defp add_comparison_results(row, comparison_map, query, true = _include_comparisons) do
    comparison_metrics = get_comparison_metrics(comparison_map, row.dimensions, query)

    change =
      Enum.zip([query.metrics, row.metrics, comparison_metrics])
      |> Enum.map(fn {metric, metric_value, comparison_value} ->
        Plausible.Stats.Compare.calculate_change(metric, comparison_value, metric_value)
      end)

    Map.merge(row, %{
      comparison: %{
        metrics: comparison_metrics,
        change: change
      }
    })
  end

  defp get_comparison_metrics(comparison_map, dimensions, query) do
    if Map.has_key?(comparison_map, dimensions) do
      Map.fetch!(comparison_map, dimensions)
    else
      Enum.map(query.metrics, fn _ -> 0 end)
    end
  end

  defp extra_meta(query, ch_results) do
    %{
      total_rows: if(query.include.total_rows, do: total_rows(ch_results), else: nil)
    }
  end

  defp total_rows([]), do: 0
  defp total_rows([first_row | _rest]), do: first_row.total_rows
end
