defmodule Plausible.Stats.Aggregate do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  @event_metrics ["visitors", "pageviews"]
  @session_metrics ["bounce_rate", "visit_duration"]

  def aggregate(site, query, metrics) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = Task.async(fn -> aggregate_events(site, query, event_metrics) end)
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = Task.async(fn -> aggregate_sessions(site, query, session_metrics) end)

    Map.merge(
      Task.await(event_task),
      Task.await(session_task)
    )
    |> Enum.map(fn {metric, value} ->
      {metric, %{value: value || 0}}
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

  defp select_session_metric("visit_duration", q) do
    from(s in q, select_merge: %{visit_duration: fragment("round(avg(duration * sign))")})
  end
end
