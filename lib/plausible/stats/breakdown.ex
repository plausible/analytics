defmodule Plausible.Stats.Breakdown do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.{Base, Imported, Util}
  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.Query
  alias Plausible.Goals
  @no_ref "Direct / None"
  @not_set "(not set)"

  @event_metrics [:visitors, :pageviews, :events]
  @session_metrics [:visits, :bounce_rate, :visit_duration]
  @event_props Plausible.Stats.Props.event_props()

  def breakdown(site, query, "event:goal" = property, metrics, pagination) do
    {event_goals, pageview_goals} =
      site.domain
      |> Goals.for_domain()
      |> Enum.split_with(fn goal -> goal.event_name end)

    events = Enum.map(event_goals, & &1.event_name)
    event_query = %Query{query | filters: Map.put(query.filters, "event:name", {:member, events})}

    trace(query, property, metrics)

    event_results =
      if Enum.any?(event_goals) do
        breakdown(site, event_query, "event:name", metrics, pagination)
        |> transform_keys(%{name: :goal})
      else
        []
      end

    {limit, page} = pagination
    offset = (page - 1) * limit

    page_results =
      if Enum.any?(pageview_goals) do
        page_exprs = Enum.map(pageview_goals, & &1.page_path)
        page_regexes = Enum.map(page_exprs, &page_regex/1)

        from(e in base_event_query(site, query),
          order_by: [desc: fragment("uniq(?)", e.user_id)],
          limit: ^limit,
          offset: ^offset,
          where:
            fragment(
              "notEmpty(multiMatchAllIndices(?, ?) as indices)",
              e.pathname,
              ^page_regexes
            ),
          group_by: fragment("index"),
          select: %{
            index: fragment("arrayJoin(indices) as index"),
            goal: fragment("concat('Visit ', ?[index])", ^page_exprs)
          }
        )
        |> select_event_metrics(metrics)
        |> ClickhouseRepo.all()
        |> Enum.map(fn row -> Map.delete(row, :index) end)
      else
        []
      end

    zip_results(event_results, page_results, :goal, metrics)
  end

  def breakdown(site, query, "event:props:" <> custom_prop = property, metrics, pagination) do
    {limit, _} = pagination

    none_result =
      if !Enum.any?(query.filters, fn {key, _} -> String.starts_with?(key, "event:props") end) do
        none_filters = Map.put(query.filters, "event:props:" <> custom_prop, {:is, "(none)"})
        none_query = %Query{query | filters: none_filters}

        from(e in base_event_query(site, none_query),
          order_by: [desc: fragment("uniq(?)", e.user_id)],
          select: %{},
          select_merge: %{^custom_prop => "(none)"},
          having: fragment("uniq(?)", e.user_id) > 0
        )
        |> select_event_metrics(metrics)
        |> ClickhouseRepo.all()
      else
        []
      end

    trace(query, property, metrics)
    results = breakdown_events(site, query, "event:props:" <> custom_prop, metrics, pagination)

    zipped = zip_results(none_result, results, custom_prop, metrics)

    if Enum.find_index(zipped, fn value -> value[custom_prop] == "(none)" end) == limit do
      Enum.slice(zipped, 0..(limit - 1))
    else
      zipped
    end
  end

  def breakdown(site, query, "event:page" = property, metrics, pagination) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    event_result = breakdown_events(site, query, "event:page", event_metrics, pagination)

    event_result =
      if :time_on_page in metrics do
        pages = Enum.map(event_result, & &1[:page])
        time_on_page_result = breakdown_time_on_page(site, query, pages)

        Enum.map(event_result, fn row ->
          Map.put(row, :time_on_page, time_on_page_result[row[:page]])
        end)
      else
        event_result
      end

    new_query =
      case event_result do
        [] ->
          query

        pages ->
          Query.put_filter(query, "visit:entry_page", {:member, Enum.map(pages, & &1[:page])})
      end

    trace(new_query, property, metrics)

    if Enum.any?(event_metrics) && Enum.empty?(event_result) do
      []
    else
      {limit, _page} = pagination

      session_result =
        breakdown_sessions(site, new_query, "visit:entry_page", session_metrics, {limit, 1})
        |> transform_keys(%{entry_page: :page})

      metrics = metrics ++ [:page]

      zip_results(
        event_result,
        session_result,
        :page,
        metrics
      )
      |> Enum.map(&Map.take(&1, metrics))
    end
  end

  def breakdown(site, query, property, metrics, pagination) when property in @event_props do
    trace(query, property, metrics)
    breakdown_events(site, query, property, metrics, pagination)
  end

  def breakdown(site, query, property, metrics, pagination)
      when property in [
             "visit:source",
             "visit:utm_medium",
             "visit:utm_source",
             "visit:utm_campaign",
             "visit:utm_content",
             "visit:utm_term"
           ] do
    query =
      query
      |> Query.treat_page_filter_as_entry_page()
      |> Query.treat_prop_filter_as_entry_prop()

    trace(query, property, metrics)
    breakdown_sessions(site, query, property, metrics, pagination)
  end

  def breakdown(site, query, property, metrics, pagination) do
    trace(query, property, metrics)
    breakdown_sessions(site, query, property, metrics, pagination)
  end

  defp zip_results(event_result, session_result, property, metrics) do
    sort_by = if Enum.member?(metrics, :visitors), do: :visitors, else: List.first(metrics)

    property =
      if is_binary(property) do
        property
        |> String.trim_leading("event:")
        |> String.trim_leading("visit:")
        |> String.trim_leading("props:")
      else
        property
      end

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

  defp breakdown_sessions(site, query, property, metrics, pagination) do
    from(s in query_sessions(site, query),
      order_by: [desc: fragment("uniq(?)", s.user_id), asc: fragment("min(?)", s.start)],
      select: %{}
    )
    |> filter_converted_sessions(site, query)
    |> do_group_by(property)
    |> select_session_metrics(metrics)
    |> merge_imported(site, query, property, metrics)
    |> apply_pagination(pagination)
    |> ClickhouseRepo.all()
    |> transform_keys(%{operating_system: :os})
    |> remove_internal_visits_metric(metrics)
  end

  defp breakdown_events(_, _, _, [], _), do: []

  defp breakdown_events(site, query, property, metrics, pagination) do
    from(e in base_event_query(site, query),
      order_by: [desc: fragment("uniq(?)", e.user_id)],
      select: %{}
    )
    |> do_group_by(property)
    |> select_event_metrics(metrics)
    |> merge_imported(site, query, property, metrics)
    |> apply_pagination(pagination)
    |> ClickhouseRepo.all()
    |> transform_keys(%{operating_system: :os})
  end

  defp breakdown_time_on_page(_site, _query, []) do
    []
  end

  defp breakdown_time_on_page(site, query, pages) do
    q =
      from(
        e in base_event_query(site, Query.remove_event_filters(query, [:page, :props])),
        select: {
          fragment("? as p", e.pathname),
          fragment("? as t", e.timestamp),
          fragment("? as s", e.session_id)
        },
        order_by: [e.session_id, e.timestamp]
      )

    {base_query_raw, base_query_raw_params} = ClickhouseRepo.to_sql(:all, q)

    select =
      if query.include_imported do
        "sum(td), count(case when p2 != p then 1 end)"
      else
        "round(sum(td)/count(case when p2 != p then 1 end))"
      end

    pages_idx = length(base_query_raw_params)
    params = base_query_raw_params ++ [pages]

    time_query = "
      SELECT
        p,
        #{select}
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
        WHERE s=s2 AND p IN {$#{pages_idx}:Array(String)}
        GROUP BY p,p2,s)
      GROUP BY p"

    {:ok, res} = ClickhouseRepo.query(time_query, params)

    if query.include_imported do
      # Imported page views have pre-calculated values
      res =
        res.rows
        |> Enum.map(fn [page, time, visits] -> {page, {time, visits}} end)
        |> Enum.into(%{})

      from(
        i in "imported_pages",
        group_by: i.page,
        where: i.site_id == ^site.id,
        where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
        where: i.page in ^pages,
        select: %{
          page: i.page,
          pageviews: fragment("sum(?) - sum(?)", i.pageviews, i.exits),
          time_on_page: sum(i.time_on_page)
        }
      )
      |> ClickhouseRepo.all()
      |> Enum.reduce(res, fn %{page: page, pageviews: pageviews, time_on_page: time}, res ->
        {restime, resviews} = Map.get(res, page, {0, 0})
        Map.put(res, page, {restime + time, resviews + pageviews})
      end)
      |> Enum.map(fn
        {page, {_, 0}} -> {page, nil}
        {page, {time, pageviews}} -> {page, time / pageviews}
      end)
      |> Enum.into(%{})
    else
      res.rows |> Enum.map(fn [page, time] -> {page, time} end) |> Enum.into(%{})
    end
  end

  defp joins_table?(ecto_q, table) do
    Enum.any?(
      ecto_q.joins,
      fn
        %Ecto.Query.JoinExpr{source: {^table, _}} -> true
        _ -> false
      end
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:props:" <> prop
       ) do
    q =
      if joins_table?(q, "meta") do
        q
      else
        from(
          e in q,
          inner_lateral_join: meta in fragment("meta"),
          as: :meta
        )
      end

    from(
      [e, meta: meta] in q,
      where: meta.key == ^prop,
      group_by: meta.value,
      select_merge: %{^prop => meta.value},
      order_by: {:asc, meta.value}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:name"
       ) do
    from(
      e in q,
      group_by: e.name,
      select_merge: %{name: e.name},
      order_by: {:asc, e.name}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events", _}}} = q,
         "event:page"
       ) do
    from(
      e in q,
      group_by: e.pathname,
      select_merge: %{page: e.pathname},
      order_by: {:asc, e.pathname}
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
            index: fragment("arrayJoin(indices) as index"),
            page_match: fragment("?[index]", ^match_exprs)
          },
          order_by: {:asc, fragment("index")}
        )
    end
  end

  defp do_group_by(q, "visit:source") do
    from(
      s in q,
      group_by: s.referrer_source,
      select_merge: %{
        source: fragment("if(empty(?), ?, ?)", s.referrer_source, @no_ref, s.referrer_source)
      },
      order_by: {:asc, s.referrer_source}
    )
  end

  defp do_group_by(q, "visit:country") do
    from(
      s in q,
      where: s.country_code != "\0\0" and s.country_code != "ZZ",
      group_by: s.country_code,
      select_merge: %{country: s.country_code},
      order_by: {:asc, s.country_code}
    )
  end

  defp do_group_by(q, "visit:region") do
    from(
      s in q,
      where: s.subdivision1_code != "",
      group_by: s.subdivision1_code,
      select_merge: %{region: s.subdivision1_code},
      order_by: {:asc, s.subdivision1_code}
    )
  end

  defp do_group_by(q, "visit:city") do
    from(
      s in q,
      where: s.city_geoname_id != 0,
      group_by: s.city_geoname_id,
      select_merge: %{city: s.city_geoname_id},
      order_by: {:asc, s.city_geoname_id}
    )
  end

  defp do_group_by(q, "visit:entry_page") do
    from(
      s in q,
      group_by: s.entry_page,
      select_merge: %{entry_page: s.entry_page},
      order_by: {:asc, s.entry_page}
    )
  end

  defp do_group_by(q, "visit:exit_page") do
    from(
      s in q,
      group_by: s.exit_page,
      select_merge: %{exit_page: s.exit_page},
      order_by: {:asc, s.exit_page}
    )
  end

  defp do_group_by(q, "visit:referrer") do
    from(
      s in q,
      group_by: s.referrer,
      select_merge: %{
        referrer: fragment("if(empty(?), ?, ?)", s.referrer, @no_ref, s.referrer)
      },
      order_by: {:asc, s.referrer}
    )
  end

  defp do_group_by(q, "visit:utm_medium") do
    from(
      s in q,
      group_by: s.utm_medium,
      select_merge: %{
        utm_medium: fragment("if(empty(?), ?, ?)", s.utm_medium, @no_ref, s.utm_medium)
      }
    )
  end

  defp do_group_by(q, "visit:utm_source") do
    from(
      s in q,
      group_by: s.utm_source,
      select_merge: %{
        utm_source: fragment("if(empty(?), ?, ?)", s.utm_source, @no_ref, s.utm_source)
      }
    )
  end

  defp do_group_by(q, "visit:utm_campaign") do
    from(
      s in q,
      group_by: s.utm_campaign,
      select_merge: %{
        utm_campaign: fragment("if(empty(?), ?, ?)", s.utm_campaign, @no_ref, s.utm_campaign)
      }
    )
  end

  defp do_group_by(q, "visit:utm_content") do
    from(
      s in q,
      group_by: s.utm_content,
      select_merge: %{
        utm_content: fragment("if(empty(?), ?, ?)", s.utm_content, @no_ref, s.utm_content)
      }
    )
  end

  defp do_group_by(q, "visit:utm_term") do
    from(
      s in q,
      group_by: s.utm_term,
      select_merge: %{
        utm_term: fragment("if(empty(?), ?, ?)", s.utm_term, @no_ref, s.utm_term)
      }
    )
  end

  defp do_group_by(q, "visit:device") do
    from(
      s in q,
      group_by: s.screen_size,
      select_merge: %{
        device: fragment("if(empty(?), ?, ?)", s.screen_size, @not_set, s.screen_size)
      },
      order_by: {:asc, s.screen_size}
    )
  end

  defp do_group_by(q, "visit:os") do
    from(
      s in q,
      group_by: s.operating_system,
      select_merge: %{
        operating_system:
          fragment("if(empty(?), ?, ?)", s.operating_system, @not_set, s.operating_system)
      },
      order_by: {:asc, s.operating_system}
    )
  end

  defp do_group_by(q, "visit:os_version") do
    from(
      s in q,
      group_by: s.operating_system_version,
      select_merge: %{
        os_version:
          fragment(
            "if(empty(?), ?, ?)",
            s.operating_system_version,
            @not_set,
            s.operating_system_version
          )
      },
      order_by: {:asc, s.operating_system_version}
    )
  end

  defp do_group_by(q, "visit:browser") do
    from(
      s in q,
      group_by: s.browser,
      select_merge: %{
        browser: fragment("if(empty(?), ?, ?)", s.browser, @not_set, s.browser)
      },
      order_by: {:asc, s.browser}
    )
  end

  defp do_group_by(q, "visit:browser_version") do
    from(
      s in q,
      group_by: s.browser_version,
      select_merge: %{
        browser_version:
          fragment("if(empty(?), ?, ?)", s.browser_version, @not_set, s.browser_version)
      },
      order_by: {:asc, s.browser_version}
    )
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end

  defp apply_pagination(q, {limit, page}) do
    offset = (page - 1) * limit

    q
    |> Ecto.Query.limit(^limit)
    |> Ecto.Query.offset(^offset)
  end

  defp trace(query, property, metrics) do
    Query.trace(query)

    Tracer.set_attributes([
      {"plausible.query.breakdown_property", property},
      {"plausible.query.breakdown_metrics", metrics}
    ])
  end
end
