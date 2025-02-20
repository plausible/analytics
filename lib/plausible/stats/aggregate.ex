defmodule Plausible.Stats.Aggregate do
  @moduledoc """
  Builds aggregate results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, QueryRunner, QueryResult, QueryOptimizer}

  def aggregate(site, query, metrics) do
    Query.trace(query, metrics)

    query =
      query
      |> Query.set(metrics: metrics, remove_unavailable_revenue_metrics: true)
      |> Query.set_include(:dashboard_imports_meta, true)
      |> QueryOptimizer.optimize()

    %QueryResult{results: [entry], meta: meta} = QueryRunner.run(site, query)

    results =
      query.metrics
      |> Enum.with_index()
      |> Enum.map(fn {metric, index} ->
        {
          metric,
          metric_map(entry, index, metric)
        }
      end)
      |> Enum.into(%{})

    %{results: results, meta: meta}
  end

  def metric_map(
        %{metrics: metrics, comparison: %{metrics: comparison_metrics, change: change}},
        index,
        metric
      ) do
    %{
      value: get_value(metrics, index, metric),
      comparison_value: get_value(comparison_metrics, index, metric),
      change: Enum.at(change, index)
    }
  end

  def metric_map(%{metrics: metrics}, index, metric) do
    %{
      value: get_value(metrics, index, metric)
    }
  end

  def get_value(metric_list, index, metric) do
    metric_list
    |> Enum.at(index)
    |> maybe_round_value(metric)
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value(nil, _metric), do: nil
  defp maybe_round_value(value, metric) when metric in @metrics_to_round, do: round(value)
  defp maybe_round_value(value, _metric), do: value
end
