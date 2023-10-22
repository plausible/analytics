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

    timed_pages_q =
      from e in subquery(windowed_pages_q),
        select: fragment("avgIf(?,?)", e.next_timestamp - e.timestamp, e.next_timestamp != 0)

    timed_filtered_pages_q =
      case query.filters["event:page"] do
        {:is, page} ->
          where(timed_pages_q, pathname: ^page)

        {:is_not, page} ->
          where(timed_pages_q, [e], e.pathname != ^page)

        {:member, pages} ->
          where(timed_pages_q, [e], e.pathname in ^pages)

        {:not_member, pages} ->
          where(timed_pages_q, [e], e.pathname not in ^pages)

        {:matches, expr} ->
          where(timed_pages_q, [e], fragment("match(?,?)", e.pathname, ^page_regex(expr)))

        {:matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          where(timed_pages_q, [e], fragment("multiMatchAny(?,?)", e.pathname, ^page_regexes))

        {:not_matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          where(timed_pages_q, [e], not fragment("multiMatchAny(?,?)", e.pathname, ^page_regexes))

        {:does_not_match, expr} ->
          where(timed_pages_q, [e], not fragment("match(?,?)", e.pathname, ^page_regex(expr)))
      end

    %{time_on_page: ClickhouseRepo.one(timed_filtered_pages_q)}
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value({metric, nil}), do: {metric, 0}

  defp maybe_round_value({metric, value}) when metric in @metrics_to_round do
    {metric, round(value)}
  end

  defp maybe_round_value(entry), do: entry
end
