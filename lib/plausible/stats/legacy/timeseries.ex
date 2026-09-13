defmodule Plausible.Stats.Legacy.Timeseries do
  @moduledoc """
  Builds timeseries results for the Stats API v1. Avoid adding new logic here.
  """

  use Plausible
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, QueryRunner, Metrics, QueryOptimizer}

  def timeseries(site, query, metrics) do
    [time_dimension] = query.dimensions

    query =
      query
      |> Query.set(
        metrics: transform_metrics(metrics, %{conversion_rate: :group_conversion_rate}),
        order_by: [{time_dimension, :asc}]
      )
      |> Query.set_include(:drop_unavailable_revenue_metrics, true)
      |> Query.set_include(:time_labels, true)
      |> Query.set_include(:time_label_result_indices, true)
      |> QueryOptimizer.optimize()

    query_result = QueryRunner.run(site, query)

    {
      build_result(query_result, query),
      query_result.meta
    }
  end

  # Given a query result, build a legacy timeseries result
  # Format is %{ date => %{ date: date_string, [metric] => value } } with a bunch of special cases for the UI
  defp build_result(query_result, %Query{} = query) do
    indexed_results =
      query_result.results |> Enum.with_index() |> Map.new(fn {row, i} -> {i, row} end)

    Enum.zip(query_result.meta[:time_labels], query_result.meta[:time_label_result_indices])
    |> Enum.map(fn {label, index} ->
      case Map.get(indexed_results, index) do
        nil -> empty_row(label, query.metrics, query)
        row -> Enum.zip(query.metrics, row.metrics) |> Map.new() |> Map.put(:date, label)
      end
    end)
    |> transform_realtime_labels(query)
    |> transform_keys(%{group_conversion_rate: :conversion_rate})
  end

  defp empty_row(date, metrics, query) do
    metrics
    |> Map.new(fn metric -> {metric, Metrics.default_value(metric, query, [date])} end)
    |> Map.put(:date, date)
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

  defp transform_realtime_labels(results, %Query{input_date_range: :realtime_30m}) do
    Enum.with_index(results)
    |> Enum.map(fn {entry, index} -> %{entry | date: -30 + index} end)
  end

  defp transform_realtime_labels(results, _query), do: results
end
