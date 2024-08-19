defmodule Plausible.Stats.Aggregate do
  @moduledoc """
  Builds aggregate results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible
  import Plausible.Stats.Base
  import Ecto.Query
  alias Plausible.Stats.{Query, Util, SQL}

  def aggregate(site, query, metrics) do
    {currency, metrics} =
      on_ee do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    Query.trace(query, metrics)

    query_with_metrics = %Query{query | metrics: metrics}

    q = Plausible.Stats.SQL.QueryBuilder.build(query_with_metrics, site)

    time_on_page_task =
      if :time_on_page in query_with_metrics.metrics do
        fn -> aggregate_time_on_page(site, query) end
      else
        fn -> %{} end
      end

    Plausible.ClickhouseRepo.parallel_tasks([
      run_query_task(q, query),
      time_on_page_task
    ])
    |> Enum.reduce(%{}, fn aggregate, task_result -> Map.merge(aggregate, task_result) end)
    |> Util.keep_requested_metrics(metrics)
    |> cast_revenue_metrics_to_money(currency)
    |> Enum.map(&maybe_round_value/1)
    |> Enum.map(fn {metric, value} -> {metric, %{value: value}} end)
    |> Enum.into(%{})
  end

  defp run_query_task(nil, _query), do: fn -> %{} end
  defp run_query_task(q, query), do: fn -> ClickhouseRepo.one(q, query: query) end

  defp aggregate_time_on_page(site, query) do
    windowed_pages_q =
      from e in base_event_query(site, Query.remove_filters(query, ["event:page"])),
        select: %{
          next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :event_horizon),
          next_pathname: over(fragment("leadInFrame(?)", e.pathname), :event_horizon),
          timestamp: e.timestamp,
          pathname: e.pathname,
          session_id: e.session_id
        },
        windows: [
          event_horizon: [
            partition_by: e.session_id,
            order_by: e.timestamp,
            frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
          ]
        ]

    event_page_filter = Query.get_filter(query, "event:page")

    timed_page_transitions_q =
      from e in Ecto.Query.subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: ^SQL.WhereBuilder.build_condition(:pathname, event_page_filter),
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }

    avg_time_per_page_transition_q =
      from e in Ecto.Query.subquery(timed_page_transitions_q),
        select: %{avg: fragment("sum(?)/countIf(?)", e.duration, e.transition)},
        group_by: e.pathname

    time_on_page_q =
      from e in Ecto.Query.subquery(avg_time_per_page_transition_q),
        select: fragment("avg(ifNotFinite(?,NULL))", e.avg)

    %{time_on_page: ClickhouseRepo.one(time_on_page_q, query: query)}
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
