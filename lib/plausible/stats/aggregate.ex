defmodule Plausible.Stats.Aggregate do
  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.{Base, Imported, Util}
  import Ecto.Query

  @event_metrics [
    :visitors,
    :pageviews,
    :events,
    :sample_percent,
    :average_revenue,
    :total_revenue
  ]
  @session_metrics [:visits, :bounce_rate, :visit_duration, :views_per_visit, :sample_percent]

  def aggregate(site, query, metrics) do
    {currency, metrics} = get_revenue_tracking_currency(site, query, metrics)

    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = fn -> aggregate_events(site, query, event_metrics) end
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = fn -> aggregate_sessions(site, query, session_metrics) end

    time_on_page_task =
      if :time_on_page in metrics do
        fn -> aggregate_time_on_page(site, query) end
      else
        fn -> %{} end
      end

    Plausible.ClickhouseRepo.parallel_tasks([session_task, event_task, time_on_page_task])
    |> Enum.reduce(%{}, fn aggregate, task_result -> Map.merge(aggregate, task_result) end)
    |> cast_revenue_metrics_to_money(currency)
    |> Enum.map(&maybe_round_value/1)
    |> Enum.map(fn {metric, value} -> {metric, %{value: value}} end)
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
    from(e in query_sessions(site, query), select: %{})
    |> filter_converted_sessions(site, query)
    |> select_session_metrics(metrics, query)
    |> merge_imported(site, query, :aggregate, metrics)
    |> ClickhouseRepo.one()
    |> remove_internal_visits_metric()
  end

  defp aggregate_time_on_page(site, query) do
    if FunWithFlags.enabled?(:window_time_on_page) do
      window_aggregate_time_on_page(site, query)
    else
      neighbor_aggregate_time_on_page(site, query)
    end
  end

  defp neighbor_aggregate_time_on_page(site, query) do
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
    where_param_idx = length(base_query_raw_params)

    {where_clause, where_arg} =
      case query.filters["event:page"] do
        {:is, page} ->
          {"p = {$#{where_param_idx}:String}", page}

        {:is_not, page} ->
          {"p != {$#{where_param_idx}:String}", page}

        {:member, page} ->
          {"p IN {$#{where_param_idx}:Array(String)}", page}

        {:not_member, page} ->
          {"p NOT IN {$#{where_param_idx}:Array(String)}", page}

        {:matches, expr} ->
          regex = page_regex(expr)
          {"match(p, {$#{where_param_idx}:String})", regex}

        {:matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          {"multiMatchAny(p, {$#{where_param_idx}:Array(String)})", page_regexes}

        {:not_matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          {"not(multiMatchAny(p, {$#{where_param_idx}:Array(String)}))", page_regexes}

        {:does_not_match, expr} ->
          regex = page_regex(expr)
          {"not(match(p, {$#{where_param_idx}:String}))", regex}
      end

    params = base_query_raw_params ++ [where_arg]

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

    {:ok, res} = ClickhouseRepo.query(time_query, params)
    [[time_on_page]] = res.rows
    %{time_on_page: time_on_page}
  end

  defp window_aggregate_time_on_page(site, query) do
    import Ecto.Query

    windowed_pages_q =
      from e in base_event_query(site, %Query{
             query
             | filters: Map.delete(query.filters, "event:page")
           }),
           select: %{
             next_timestamp:
               over(fragment("leadInFrame(?)", e.timestamp),
                 partition_by: e.session_id,
                 order_by: e.timestamp,
                 frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
               ),
             timestamp: e.timestamp,
             pathname: e.pathname
           }

    time_on_page_q =
      from e in subquery(windowed_pages_q),
        select: fragment("avgIf(?,?)", e.next_timestamp - e.timestamp, e.next_timestamp != 0),
        where: ^Plausible.Stats.Base.dynamic_filter_condition(query, "event:page", :pathname)

    %{time_on_page: ClickhouseRepo.one(time_on_page_q)}
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value({metric, nil}), do: {metric, 0}

  defp maybe_round_value({metric, value}) when metric in @metrics_to_round do
    {metric, round(value)}
  end

  defp maybe_round_value(entry), do: entry
end
