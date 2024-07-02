defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, QueryOptimizer, QueryResult, SQL}

  @time_dimension %{
    "month" => "time:month",
    "week" => "time:week",
    "date" => "time:day",
    "hour" => "time:hour"
  }

  def timeseries(site, query, metrics) do
    query_with_metrics =
      Query.set(
        query,
        metrics: transform_metrics(metrics, %{conversion_rate: :group_conversion_rate}),
        dimensions: [time_dimension(query)],
        order_by: [{time_dimension(query), :asc}],
        v2: true,
        include: %{time_labels: true, imports: query.include.imports}
      )
      |> QueryOptimizer.optimize()

    q = SQL.QueryBuilder.build(query_with_metrics, site)

    q
    |> ClickhouseRepo.all()
    |> QueryResult.from(query_with_metrics)
    |> build_timeseries_result(query_with_metrics)
    |> transform_keys(%{group_conversion_rate: :conversion_rate})
  end

  defp time_dimension(query), do: Map.fetch!(@time_dimension, query.interval)

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
        :group_conversion_rate -> Map.merge(row, %{group_conversion_rate: 0.0})
        :bounce_rate -> Map.merge(row, %{bounce_rate: 0.0})
        :visit_duration -> Map.merge(row, %{visit_duration: nil})
        :average_revenue -> Map.merge(row, %{average_revenue: nil})
        :total_revenue -> Map.merge(row, %{total_revenue: nil})
      end
    end)
  end

  defp transform_metrics(metrics, to_replace) do
    Enum.map(metrics, &Map.get(to_replace, &1, &1))
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end
end
