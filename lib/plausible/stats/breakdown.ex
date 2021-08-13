defmodule Plausible.Stats.Breakdown do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base
  alias Plausible.Stats.Query
  @no_ref "Direct / None"

  @event_metrics ["visitors", "pageviews", "events"]
  @session_metrics ["visits", "bounce_rate", "visit_duration"]
  @event_props ["event:page", "event:page_match", "event:name"]

  def breakdown(site, query, "visit:goal", metrics, pagination) do
    {event_goals, pageview_goals} =
      Plausible.Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
      |> Enum.split_with(fn goal -> goal.event_name end)

    events = Enum.map(event_goals, & &1.event_name)
    event_query = %Query{query | filters: Map.put(query.filters, "event:name", {:member, events})}

    event_goals =
      breakdown(site, event_query, "event:name", metrics, pagination)
      |> transform_keys(%{"name" => "goal"})

    page_exprs = Enum.map(pageview_goals, & &1.page_path)
    page_regexes = Enum.map(page_exprs, &page_regex/1)

    {limit, page} = pagination
    offset = (page - 1) * limit

    page_goals =
      from(e in base_event_query(site, query),
        order_by: [desc: fragment("uniq(?)", e.user_id)],
        limit: ^limit,
        offset: ^offset,
        where:
          fragment(
            "notEmpty(multiMatchAllIndices(?, array(?)) as indices)",
            e.pathname,
            ^page_regexes
          ),
        group_by: fragment("index"),
        select: %{
          "index" => fragment("arrayJoin(indices) as index"),
          "goal" => fragment("concat('Visit ', array(?)[index])", ^page_exprs)
        }
      )
      |> select_event_metrics(metrics)
      |> ClickhouseRepo.all()
      |> Enum.map(fn row -> Map.delete(row, "index") end)

    zip_results(event_goals, page_goals, "visit:goal", metrics)
  end

  def breakdown(site, query, "event:props:" <> custom_prop, metrics, pagination) do
    none_result =
      if !Enum.any?(query.filters, fn {key, _} -> String.starts_with?(key, "event:props") end) do
        none_filters = Map.put(query.filters, "event:props:" <> custom_prop, {:is, "(none)"})
        none_query = %Query{query | filters: none_filters}

        {limit, page} = pagination
        offset = (page - 1) * limit

        from(e in base_event_query(site, none_query),
          order_by: [desc: fragment("uniq(?)", e.user_id)],
          limit: ^limit,
          offset: ^offset,
          select: %{},
          select_merge: %{^custom_prop => "(none)"},
          having: fragment("uniq(?)", e.user_id) > 0
        )
        |> select_event_metrics(metrics)
        |> ClickhouseRepo.all()
      else
        []
      end

    results = breakdown_events(site, query, "event:props:" <> custom_prop, metrics, pagination)
    zip_results(none_result, results, custom_prop, metrics)
  end

  def breakdown(site, query, "event:page", metrics, pagination) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    event_result = breakdown_events(site, query, "event:page", event_metrics, pagination)

    event_result =
      if "time_on_page" in metrics do
        pages = Enum.map(event_result, & &1["page"])
        time_on_page_result = breakdown_time_on_page(site, query, pages)

        Enum.map(event_result, fn row ->
          Map.put(row, "time_on_page", time_on_page_result[row["page"]])
        end)
      else
        event_result
      end

    new_query =
      case event_result do
        [] ->
          query

        pages ->
          new_filters =
            Map.put(query.filters, "event:page", {:member, Enum.map(pages, & &1["page"])})

          %Query{query | filters: new_filters}
      end

    {limit, _page} = pagination

    session_result =
      breakdown_sessions(site, new_query, "visit:entry_page", session_metrics, {limit, 1})
      |> transform_keys(%{"entry_page" => "page"})

    zip_results(
      event_result,
      session_result,
      "event:page",
      metrics
    )
  end

  def breakdown(site, query, property, metrics, pagination) when property in @event_props do
    breakdown_events(site, query, property, metrics, pagination)
  end

  def breakdown(site, query, property, metrics, pagination) do
    breakdown_sessions(site, query, property, metrics, pagination)
  end

  defp zip_results(event_result, session_result, property, metrics) do
    sort_by = if Enum.member?(metrics, "visitors"), do: "visitors", else: List.first(metrics)

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
    |> Enum.sort_by(fn row -> row[sort_by] end, :desc)
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
    if query.filters["event:name"] || query.filters["event:page"] || query.filters["visit:goal"] do
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

  defp breakdown_time_on_page(site, query, pages) do
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

    time_query = "
      SELECT
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
        WHERE s=s2 AND p IN tuple(?)
        GROUP BY p,p2,s)
      GROUP BY p"

    {:ok, res} = ClickhouseRepo.query(time_query, base_query_raw_params ++ [pages])
    res.rows |> Enum.map(fn [page, time] -> {page, time} end) |> Enum.into(%{})
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
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:page_match"
       ) do
    case Map.get(q, :__private_match_sources__) do
      match_exprs when is_list(match_exprs) ->
        from(
          e in q,
          group_by: fragment("index"),
          select_merge: %{
            "index" => fragment("arrayJoin(indices) as index"),
            "page_match" => fragment("array(?)[index]", ^match_exprs)
          }
        )
    end
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

  defp do_group_by(q, "visit:exit_page") do
    from(
      s in q,
      group_by: s.exit_page,
      select_merge: %{"exit_page" => s.exit_page}
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

  defp select_event_metrics(q, ["events" | rest]) do
    from(e in q,
      select_merge: %{"events" => fragment("count(*)")}
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

  defp select_metrics(q, ["visits" | rest]) do
    from(s in q,
      select_merge: %{
        "visits" => fragment("sum(?)", s.sign)
      }
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

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end
end
