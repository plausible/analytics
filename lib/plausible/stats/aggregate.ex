defmodule Plausible.Stats.Aggregate do
  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.{Base, Imported}

  @event_metrics [:visitors, :pageviews, :events, :sample_percent]
  @session_metrics [:visits, :bounce_rate, :visit_duration, :sample_percent]

  def aggregate(site, query, metrics) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = Task.async(fn -> aggregate_events(site, query, event_metrics) end)
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = Task.async(fn -> aggregate_sessions(site, query, session_metrics) end)

    time_on_page_task =
      if :time_on_page in metrics do
        Task.async(fn -> aggregate_time_on_page(site, query) end)
      else
        Task.async(fn -> %{} end)
      end

    Task.await(session_task, 10_000)
    |> Map.merge(Task.await(event_task, 10_000))
    |> Map.merge(Task.await(time_on_page_task, 10_000))
    |> Enum.map(fn {metric, value} ->
      {metric, %{value: round(value || 0)}}
    end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    from(e in base_event_query(site, query), select: %{})
    |> select_event_metrics(metrics)
    |> merge_imported(site, query, :aggregate, metrics)
    |> ClickhouseRepo.one()
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    query = Query.treat_page_filter_as_entry_page(query)

    from(e in query_sessions(site, query), select: %{})
    |> filter_converted_sessions(site, query)
    |> select_session_metrics(metrics)
    |> merge_imported(site, query, :aggregate, metrics)
    |> ClickhouseRepo.one()
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

        {:does_not_match, expr} ->
          regex = page_regex(expr)
          {"not(match(p, ?))", regex}
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
