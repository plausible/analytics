defmodule Plausible.Stats.Breakdown do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base
  @no_ref "Direct / None"

  @event_metrics ["visitors", "pageviews"]
  @session_metrics ["bounce_rate", "visit_duration"]
  @event_props ["event:page", "event:name"]

  def breakdown(site, query, property, metrics, pagination) do
    if property in @event_props || String.starts_with?(property, "event:props:") do
      event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
      session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

      event_task =
        Task.async(fn -> breakdown_events(site, query, property, event_metrics, pagination) end)

      session_task =
        Task.async(fn ->
          breakdown_sessions(site, query, property, session_metrics, pagination)
        end)

      zip_results(
        Task.await(event_task),
        Task.await(session_task),
        property,
        metrics
      )
    else
      breakdown_sessions(site, query, property, metrics, pagination)
    end
  end

  defp zip_results(event_result, session_result, property, metrics) do
    property =
      property
      |> String.trim_leading("event:")
      |> String.trim_leading("visit:")
      |> String.trim_leading("props:")

    null_row = Enum.map(metrics, fn metric -> {metric, nil} end) |> Enum.into(%{})

    prop_values =
      Enum.map(event_result ++ session_result, fn row -> row[property] end)
      |> Enum.uniq()

    Enum.map(prop_values, fn value ->
      event_row = Enum.find(event_result, fn row -> row[property] == value end) || %{}
      session_row = Enum.find(session_result, fn row -> row[property] == value end) || %{}

      Map.merge(null_row, event_row)
      |> Map.merge(session_row)
    end)
  end

  defp breakdown_sessions(_, _, _, [], _), do: []

  defp breakdown_sessions(site, query, property, metrics, {limit, page}) do
    offset = (page - 1) * limit

    from(s in query_sessions(site, query),
      order_by: [desc: fragment("uniq(?)", s.user_id), asc: fragment("min(?)", s.start)],
      limit: ^limit,
      offset: ^offset,
      select: %{}
    )
    |> filter_converted_sessions(site, query)
    |> do_group_by(property)
    |> select_metrics(metrics)
    |> ClickhouseRepo.all()
  end

  defp filter_converted_sessions(db_query, site, query) do
    event = query.filters["event:name"]

    if is_binary(event) do
      converted_sessions =
        from(e in query_events(site, query),
          select: %{session_id: fragment("DISTINCT ?", e.session_id)}
        )

      from(s in db_query,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id
      )
    else
      db_query
    end
  end

  defp breakdown_events(_, _, _, [], _), do: []

  defp breakdown_events(site, query, property, metrics, {limit, page}) do
    offset = (page - 1) * limit

    from(e in base_event_query(site, query),
      order_by: [desc: fragment("uniq(?)", e.user_id)],
      limit: ^limit,
      offset: ^offset,
      select: %{}
    )
    |> do_group_by(property)
    |> select_event_metrics(metrics)
    |> ClickhouseRepo.all()
  end

  defp do_group_by(
         %Ecto.Query{
           from: %Ecto.Query.FromExpr{source: {"events", _}},
           joins: [%Ecto.Query.JoinExpr{source: {"meta", _}}]
         } = q,
         "event:props:" <> prop
       ) do
    from(
      [e, meta] in q,
      group_by: e.name,
      where: meta.key == ^prop,
      group_by: meta.value,
      select_merge: %{^prop => meta.value}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:props:" <> prop
       ) do
    from(
      e in q,
      inner_lateral_join: meta in fragment("meta"),
      where: meta.key == ^prop,
      group_by: meta.value,
      select_merge: %{^prop => meta.value}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:name"
       ) do
    from(
      e in q,
      group_by: e.name,
      select_merge: %{"name" => e.name}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:page"
       ) do
    from(
      e in q,
      group_by: e.pathname,
      select_merge: %{"page" => e.pathname}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"sessions", _}}} = q,
         "event:page"
       ) do
    from(
      s in q,
      group_by: s.entry_page,
      select_merge: %{"page" => s.entry_page}
    )
  end

  defp do_group_by(q, "visit:source") do
    from(
      s in q,
      group_by: s.referrer_source,
      select_merge: %{
        "source" => fragment("if(empty(?), ?, ?)", s.referrer_source, @no_ref, s.referrer_source)
      }
    )
  end

  defp do_group_by(q, "visit:country") do
    from(
      s in q,
      group_by: s.country_code,
      where: s.country_code != "\0\0",
      select_merge: %{"country" => s.country_code}
    )
  end

  defp do_group_by(q, "visit:entry_page") do
    from(
      s in q,
      group_by: s.entry_page,
      select_merge: %{"entry_page" => s.entry_page}
    )
  end

  defp do_group_by(q, "visit:referrer") do
    from(
      s in q,
      group_by: s.referrer,
      select_merge: %{
        "referrer" => fragment("if(empty(?), ?, ?)", s.referrer, @no_ref, s.referrer)
      }
    )
  end

  defp do_group_by(q, "visit:utm_medium") do
    from(
      s in q,
      group_by: s.utm_medium,
      select_merge: %{
        "utm_medium" => fragment("if(empty(?), ?, ?)", s.utm_medium, @no_ref, s.utm_medium)
      }
    )
  end

  defp do_group_by(q, "visit:utm_source") do
    from(
      s in q,
      group_by: s.utm_source,
      select_merge: %{
        "utm_source" => fragment("if(empty(?), ?, ?)", s.utm_source, @no_ref, s.utm_source)
      }
    )
  end

  defp do_group_by(q, "visit:utm_campaign") do
    from(
      s in q,
      group_by: s.utm_campaign,
      select_merge: %{
        "utm_campaign" => fragment("if(empty(?), ?, ?)", s.utm_campaign, @no_ref, s.utm_campaign)
      }
    )
  end

  defp do_group_by(q, "visit:device") do
    from(
      s in q,
      group_by: s.screen_size,
      select_merge: %{"device" => s.screen_size}
    )
  end

  defp do_group_by(q, "visit:os") do
    from(
      s in q,
      group_by: s.operating_system,
      select_merge: %{"os" => s.operating_system}
    )
  end

  defp do_group_by(q, "visit:os_version") do
    from(
      s in q,
      group_by: s.operating_system_version,
      select_merge: %{"os_version" => s.operating_system_version}
    )
  end

  defp do_group_by(q, "visit:browser") do
    from(
      s in q,
      group_by: s.browser,
      select_merge: %{"browser" => s.browser}
    )
  end

  defp do_group_by(q, "visit:browser_version") do
    from(
      s in q,
      group_by: s.browser_version,
      select_merge: %{"browser_version" => s.browser_version}
    )
  end

  defp select_event_metrics(q, []), do: q

  defp select_event_metrics(q, ["pageviews" | rest]) do
    from(e in q,
      select_merge: %{"pageviews" => fragment("countIf(? = 'pageview')", e.name)}
    )
    |> select_event_metrics(rest)
  end

  defp select_event_metrics(q, ["visitors" | rest]) do
    from(e in q,
      select_merge: %{"visitors" => fragment("uniq(?) as count", e.user_id)}
    )
    |> select_event_metrics(rest)
  end

  defp select_metrics(q, []), do: q

  defp select_metrics(q, ["pageviews" | rest]) do
    from(s in q,
      select_merge: %{"pageviews" => fragment("sum(? * ?)", s.sign, s.pageviews)}
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["visitors" | rest]) do
    from(s in q,
      select_merge: %{"visitors" => fragment("uniq(?) as count", s.user_id)}
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["bounce_rate" | rest]) do
    from(s in q,
      select_merge: %{
        "bounce_rate" => fragment("round(sum(? * ?) / sum(?) * 100)", s.is_bounce, s.sign, s.sign)
      }
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["visit_duration" | rest]) do
    from(s in q,
      select_merge: %{"visit_duration" => fragment("round(avg(? * ?))", s.duration, s.sign)}
    )
    |> select_metrics(rest)
  end
end
