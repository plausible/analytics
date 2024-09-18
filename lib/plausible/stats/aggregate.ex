defmodule Plausible.Stats.Aggregate do
  @moduledoc """
  Builds aggregate results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible
  alias Plausible.Stats.{Query, QueryExecutor}

  def aggregate(site, query, metrics) do
    {currency, metrics} =
      on_ee do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    Query.trace(query, metrics)

    query = %Query{query | metrics: metrics}
    query_result = QueryExecutor.execute(site, query)

    [entry] = query_result.results

    query.metrics
    |> Enum.with_index()
    |> Enum.map(fn {metric, index} ->
      {
        metric,
        %{
          value:
            entry.metrics
            |> Enum.at(index)
            |> maybe_round_value(metric)
            |> maybe_cast_metric_to_money(metric, currency)
        }
      }
    end)
    |> Enum.into(%{})
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value(nil, _metric), do: nil
  defp maybe_round_value(value, metric) when metric in @metrics_to_round, do: round(value)
  defp maybe_round_value(value, _metric), do: value

  on_ee do
    defp maybe_cast_metric_to_money(value, metric, currency) do
      Plausible.Stats.Goal.Revenue.maybe_cast_metric_to_money(value, metric, currency)
    end
  else
    defp maybe_cast_metric_to_money(value, _metric, _currency), do: value
  end
end
