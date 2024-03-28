defmodule Plausible.Stats.Aggregate do
  use Plausible.ClickhouseRepo
  use Plausible
  import Plausible.Stats.{Base, Imported}
  import Ecto.Query
  alias Plausible.Stats.{Query, Util}

  @revenue_metrics on_full_build(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])

  @event_metrics [
                   :visitors,
                   :pageviews,
                   :events,
                   :sample_percent,
                   :conversion_rate,
                   :total_visitors
                 ] ++ @revenue_metrics

  @session_metrics [:visits, :bounce_rate, :visit_duration, :views_per_visit, :sample_percent]

  def aggregate(site, query, metrics) do
    IO.inspect(metrics, label: :metrics)

    {currency, metrics} =
      on_full_build do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    Query.trace(query, metrics)

    event_metrics =
      metrics
      |> Util.maybe_add_visitors_metric()
      |> Enum.filter(&(&1 in @event_metrics))

    event_task = fn -> aggregate_events(site, query, event_metrics) end

    session_metrics =
      Enum.filter(metrics, &(&1 in @session_metrics))
      |> IO.inspect(label: :session_metrics)

    session_task = fn -> aggregate_sessions(site, query, session_metrics) end

    time_on_page_task =
      if :time_on_page in metrics do
        fn -> aggregate_time_on_page(site, query) end
      else
        fn -> %{} end
      end

    Plausible.ClickhouseRepo.parallel_tasks([session_task, event_task, time_on_page_task])
    |> Enum.reduce(%{}, fn aggregate, task_result -> Map.merge(aggregate, task_result) end)
    |> Util.keep_requested_metrics(metrics)
    |> cast_revenue_metrics_to_money(currency)
    |> Enum.map(&maybe_round_value/1)
    |> Enum.map(fn {metric, value} -> {metric, %{value: value}} end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    from(e in base_event_query(site, query), select: ^select_event_metrics(metrics))
    |> IO.inspect(label: :agg_query)
    |> merge_imported(site, query, :aggregate, metrics)
    |> maybe_add_conversion_rate(site, query, metrics, include_imported: query.include_imported)
    |> ClickhouseRepo.one()
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    from(e in query_sessions(site, query), select: ^select_session_metrics(metrics, query))
    |> filter_converted_sessions(site, query)
    |> merge_imported(site, query, :aggregate, metrics)
    |> ClickhouseRepo.one()
    |> Util.keep_requested_metrics(metrics)
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
    windowed_pages_q =
      from e in base_event_query(site, %Query{
             query
             | filters: Map.delete(query.filters, "event:page")
           }),
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

    timed_page_transitions_q =
      from e in Ecto.Query.subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: ^Plausible.Stats.Base.dynamic_filter_condition(query, "event:page", :pathname),
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

    %{time_on_page: ClickhouseRepo.one(time_on_page_q)}
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value({metric, nil}), do: {metric, nil}

  defp maybe_round_value({metric, value}) when metric in @metrics_to_round do
    {metric, round(value)}
  end

  defp maybe_round_value(entry), do: entry

  on_full_build do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end
end
