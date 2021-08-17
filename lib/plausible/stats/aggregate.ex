defmodule Plausible.Stats.Aggregate do
  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  @event_metrics ["visitors", "pageviews", "events"]
  @session_metrics ["visits", "bounce_rate", "visit_duration"]

  def aggregate(site, query, metrics) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = Task.async(fn -> aggregate_events(site, query, event_metrics) end)
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = Task.async(fn -> aggregate_sessions(site, query, session_metrics) end)

    time_on_page_task =
      if "time_on_page" in metrics do
        Task.async(fn -> aggregate_time_on_page(site, query) end)
      else
        Task.async(fn -> %{} end)
      end

    Task.await(event_task)
    |> Map.merge(Task.await(session_task))
    |> Map.merge(Task.await(time_on_page_task))
    |> Enum.map(fn {metric, value} ->
      {metric, %{value: round(value || 0)}}
    end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    q = from(e in base_event_query(site, query), select: %{})

    Enum.reduce(metrics, q, &select_event_metric/2)
    |> ClickhouseRepo.one()
  end

  defp select_event_metric("pageviews", q) do
    from(e in q,
      select_merge: %{pageviews: fragment("countIf(? = 'pageview')", e.name)}
    )
  end

  defp select_event_metric("events", q) do
    from(e in q,
      select_merge: %{events: fragment("count(*)")}
    )
  end

  defp select_event_metric("visitors", q) do
    from(e in q, select_merge: %{visitors: fragment("uniq(?)", e.user_id)})
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    q = from(e in query_sessions(site, query), select: %{})

    Enum.reduce(metrics, q, &select_session_metric/2)
    |> ClickhouseRepo.one()
  end

  defp select_session_metric("bounce_rate", q) do
    from(s in q,
      select_merge: %{bounce_rate: fragment("round(sum(is_bounce * sign) / sum(sign) * 100)")}
    )
  end

  defp select_session_metric("visits", q) do
    from(s in q,
      select_merge: %{visits: fragment("sum(?)", s.sign)}
    )
  end

  defp select_session_metric("visit_duration", q) do
    from(s in q, select_merge: %{visit_duration: fragment("round(avg(duration * sign))")})
  end

  defp aggregate_time_on_page(site, query) do
    q =
      from(
        e in base_event_query(site, %Query{
          query
          | filters: Map.delete(query.filters, "event:page")
        }),
        select: {
          fragment("? as p", e.pathname),
          fragment("? as t", e.timestamp),
          fragment("? as s", e.session_id)
        },
        order_by: [e.session_id, e.timestamp]
      )

    {base_query_raw, base_query_raw_params} = ClickhouseRepo.to_sql(:all, q)

    {where_clause, where_arg} =
      case query.filters["event:page"] do
        {:is, page} ->
          {"p = ?", page}

        {:is_not, page} ->
          {"p != ?", page}

        {:matches, expr} ->
          regex = page_regex(expr)
          {"match(p, ?)", regex}
      end

    time_query = "
      SELECT
        avg(ifNotFinite(avgTime, null))
      FROM
        (SELECT
          p,
          sum(td)/count(case when p2 != p then 1 end) as avgTime
        FROM
          (SELECT
            p,
            p2,
            sum(t2-t) as td
          FROM
            (SELECT
            *,
              neighbor(t, 1) as t2,
              neighbor(p, 1) as p2,
              neighbor(s, 1) as s2
            FROM (#{base_query_raw}))
          WHERE s=s2 AND #{where_clause}
          GROUP BY p,p2,s)
        GROUP BY p)"

    {:ok, res} = ClickhouseRepo.query(time_query, base_query_raw_params ++ [where_arg])
    [[time_on_page]] = res.rows
    %{time_on_page: time_on_page}
  end
end
