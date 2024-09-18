defmodule Plausible.Stats.Aggregate do
  @moduledoc """
  Builds aggregate results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible
  alias Plausible.Stats.{Query, QueryExecutor, Util}

  def aggregate(site, query, metrics) do
    {currency, metrics} =
      on_ee do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    Query.trace(query, metrics)

    query_with_metrics = %Query{query | metrics: metrics}

    run_query(site, query_with_metrics)
    |> cast_revenue_metrics_to_money(currency)
    |> Enum.map(&maybe_round_value/1)
    |> Enum.map(fn {metric, value} -> {metric, %{value: value}} end)
    |> Enum.into(%{})
  end

  def run_query(site, query) do
    query_result = QueryExecutor.execute(site, query)

    [%{metrics: metrics_values}] = query_result.results

    Enum.zip(query.metrics, metrics_values)
    |> Map.new()
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value({metric, nil}), do: {metric, nil}

  defp maybe_round_value({metric, value}) when metric in @metrics_to_round do
    {metric, round(value)}
  end

  defp maybe_round_value(entry), do: entry

  on_ee do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end
end
