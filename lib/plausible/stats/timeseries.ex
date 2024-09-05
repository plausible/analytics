defmodule Plausible.Stats.Timeseries do
  use Plausible
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, QueryOptimizer, QueryResult, SQL}
  alias Plausible.Stats.Goal.Revenue

  @time_dimension %{
    "month" => "time:month",
    "week" => "time:week",
    "day" => "time:day",
    "hour" => "time:hour",
    "minute" => "time:minute"
  }

  def timeseries(site, %Query{v2: false} = query, metrics) do
    v2_query =
      query
      |> Query.set(metrics: metrics)
      |> Query.set(dimensions: [time_dimension(query)])
      |> Query.set(v2: true)

    timeseries(site, v2_query)
  end

  def timeseries(site, %Query{v2: true} = query) do
    {currency, query} =
      on_ee do
        Revenue.get_revenue_tracking_currency(site, query)
      else
        {nil, query}
      end

    [time_dimension] = query.dimensions

    query =
      query
      |> Query.set(order_by: [{time_dimension, :asc}])
      |> Query.set(include: Map.put(query.include, :time_labels, :true))
      |> transform_metrics(%{conversion_rate: :group_conversion_rate})
      |> QueryOptimizer.optimize()

    q = SQL.QueryBuilder.build(query, site)

    query_result =
      q
      |> ClickhouseRepo.all(query: query)
      |> QueryResult.from(site, query)

    timeseries_result =
      query_result
      |> build_timeseries_result(query, currency)
      |> transform_keys(%{group_conversion_rate: :conversion_rate})

    {timeseries_result, query_result.meta}
  end

  defp time_dimension(query), do: Map.fetch!(@time_dimension, query.interval)

  defp build_timeseries_result(query_result, query, currency) do
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
      |> cast_revenue_metrics_to_money(currency)
    end)
    |> transform_realtime_labels(query)
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

  defp transform_metrics(%Query{metrics: metrics} = query, to_replace) do
    new_metrics = Enum.map(metrics, &Map.get(to_replace, &1, &1))
    Query.set(query, metrics: new_metrics)
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end

  defp transform_realtime_labels(results, query) do
    if query.period == "30m" or query.include[:realtime_labels] == true do
      Enum.with_index(results)
      |> Enum.map(fn {entry, index} -> %{entry | date: -30 + index} end)
    else
      results
    end
  end

  on_ee do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end
end
