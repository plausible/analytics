defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, QueryOptimizer, QueryResult, SQL}

  def timeseries(site, query, metrics) do
    query_with_metrics =
      Query.set(
        query,
        metrics: metrics,
        dimensions: [time_dimension(query)],
        order_by: [{time_dimension(query), :asc}],
        v2: true,
        include: %{time_labels: true, imports: query.include.imports}
      )
      |> QueryOptimizer.optimize()

    IO.inspect(query_with_metrics)

    q = SQL.QueryBuilder.build(query_with_metrics, site)

    q
    |> IO.inspect()
    |> ClickhouseRepo.all()
    |> QueryResult.from(query_with_metrics)
    |> build_timeseries_result(query_with_metrics)
  end

  defp time_dimension(query) do
    case query.interval do
      "month" -> "time:month"
      "week" -> "time:week"
      "date" -> "time:day"
      "hour" -> "time:hour"
    end
  end

  defp build_timeseries_result(query_result, query) do
    results_map =
      query_result.results
      |> Enum.map(fn %{dimensions: [time_dimension_value], metrics: entry_metrics} ->
        metrics_map = Enum.zip(query.metrics, entry_metrics) |> Enum.into(%{})

        {
          time_dimension_value,
          Map.put(metrics_map, :date, time_dimension_value)
        }
      end)
      |> Enum.into(%{})

    query_result.meta.time_labels
    |> Enum.map(fn key ->
      Map.get(
        results_map,
        key,
        empty_row(key, query.metrics)
      )
    end)
  end

  defp empty_row(date, metrics) do
    Enum.reduce(metrics, %{date: date}, fn metric, row ->
      case metric do
        :pageviews -> Map.merge(row, %{pageviews: 0})
        :events -> Map.merge(row, %{events: 0})
        :visitors -> Map.merge(row, %{visitors: 0})
        :visits -> Map.merge(row, %{visits: 0})
        :views_per_visit -> Map.merge(row, %{views_per_visit: 0.0})
        :conversion_rate -> Map.merge(row, %{conversion_rate: 0.0})
        :bounce_rate -> Map.merge(row, %{bounce_rate: 0.0})
        :visit_duration -> Map.merge(row, %{visit_duration: nil})
        :average_revenue -> Map.merge(row, %{average_revenue: nil})
        :total_revenue -> Map.merge(row, %{total_revenue: nil})
      end
    end)
  end
end
