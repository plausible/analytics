defmodule Plausible.Stats.Base do
  use Plausible.ClickhouseRepo
  use Plausible
  use Plausible.Stats.Fragments

  alias Plausible.Stats.{Query, Filters}
  alias Plausible.Timezones
  import Ecto.Query

  @no_ref "Direct / None"
  @not_set "(not set)"

  @uniq_users_expression "toUInt64(round(uniq(?) * any(_sample_factor)))"

  def base_event_query(site, query) do
    events_q = query_events(site, query)

    if Enum.any?(Filters.visit_props(), &query.filters["visit:" <> &1]) do
      sessions_q =
        from(
          s in query_sessions(site, query),
          select: %{session_id: s.session_id},
          where: s.sign == 1,
          group_by: s.session_id
        )

      from(
        e in events_q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      events_q
    end
  end

  def query_events(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    q =
      from(
        e in "events_v2",
        where: e.site_id == ^site.id,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    on_full_build do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q =
      q
      |> where([e], ^dynamic_filter_condition(query, "event:page", :pathname))
      |> where([e], ^dynamic_filter_condition(query, "event:hostname", :hostname))

    q =
      case query.filters["event:name"] do
        {:is, name} ->
          from(e in q, where: e.name == ^name)

        {:member, list} ->
          from(e in q, where: e.name in ^list)

        nil ->
          q
      end

    q =
      case query.filters["event:goal"] do
        {:is, {:page, path}} ->
          from(e in q, where: e.pathname == ^path and e.name == "pageview")

        {:matches, {:page, expr}} ->
          regex = page_regex(expr)

          from(e in q,
            where: fragment("match(?, ?)", e.pathname, ^regex) and e.name == "pageview"
          )

        {:is, {:event, event}} ->
          from(e in q, where: e.name == ^event)

        {:member, clauses} ->
          {events, pages} = split_goals(clauses)

          from(e in q,
            where: (e.pathname in ^pages and e.name == "pageview") or e.name in ^events
          )

        {:matches_member, clauses} ->
          {events, pages} = split_goals(clauses, &page_regex/1)

          event_clause =
            if Enum.any?(events) do
              dynamic([x], fragment("multiMatchAny(?, ?)", x.name, ^events))
            else
              dynamic([x], false)
            end

          page_clause =
            if Enum.any?(pages) do
              dynamic(
                [x],
                fragment("multiMatchAny(?, ?)", x.pathname, ^pages) and x.name == "pageview"
              )
            else
              dynamic([x], false)
            end

          where_clause = dynamic([], ^event_clause or ^page_clause)

          from(e in q, where: ^where_clause)

        nil ->
          q
      end

    q =
      Enum.reduce(
        Query.get_all_filters_by_prefix(query, "event:props"),
        q,
        &filter_by_custom_prop/2
      )

    q
  end

  @api_prop_name_to_db %{
    "source" => "referrer_source",
    "device" => "screen_size",
    "screen" => "screen_size",
    "os" => "operating_system",
    "os_version" => "operating_system_version",
    "country" => "country_code",
    "region" => "subdivision1_code",
    "city" => "city_geoname_id"
  }

  def query_sessions(site, query) do
    {first_datetime, last_datetime} =
      utc_boundaries(query, site)

    q = from(s in "sessions_v2", where: s.site_id == ^site.id)

    sessions_q =
      if FunWithFlags.enabled?(:experimental_session_count, for: site) or
           query.experimental_session_count? do
        from s in q, where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      else
        from s in q, where: s.start >= ^first_datetime and s.start < ^last_datetime
      end

    on_full_build do
      sessions_q = Plausible.Stats.Sampling.add_query_hint(sessions_q, query)
    end

    sessions_q = filter_by_entry_props(sessions_q, query)

    Enum.reduce(Filters.visit_props(), sessions_q, fn prop_name, sessions_q ->
      filter_key = "visit:" <> prop_name

      db_field =
        Map.get(@api_prop_name_to_db, prop_name, prop_name)
        |> String.to_existing_atom()

      from(s in sessions_q,
        where: ^dynamic_filter_condition(query, filter_key, db_field)
      )
    end)
  end

  def filter_by_entry_props(sessions_q, query) do
    case Query.get_filter_by_prefix(query, "visit:entry_props:") do
      nil ->
        sessions_q

      {"visit:entry_props:" <> prop_name, filter_value} ->
        apply_entry_prop_filter(sessions_q, prop_name, filter_value)
    end
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is, "(none)"}) do
    from(
      s in sessions_q,
      where: not has_key(s, :entry_meta, ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is, value}) do
    from(
      s in sessions_q,
      where:
        has_key(s, :entry_meta, ^prop_name) and get_by_key(s, :entry_meta, ^prop_name) == ^value
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is_not, "(none)"}) do
    from(
      s in sessions_q,
      where: has_key(s, :entry_meta, ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is_not, value}) do
    from(
      s in sessions_q,
      where:
        not has_key(s, :entry_meta, ^prop_name) or
          get_by_key(s, :entry_meta, ^prop_name) != ^value
    )
  end

  def apply_entry_prop_filter(sessions_q, _, _), do: sessions_q

  def select_event_metrics(metrics) do
    metrics
    |> Enum.map(&select_event_metric/1)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp select_event_metric(:pageviews) do
    %{
      pageviews:
        dynamic(
          [e],
          fragment("toUInt64(round(countIf(? = 'pageview') * any(_sample_factor)))", e.name)
        )
    }
  end

  defp select_event_metric(:events) do
    %{
      events: dynamic([], fragment("toUInt64(round(count(*) * any(_sample_factor)))"))
    }
  end

  defp select_event_metric(:visitors) do
    %{
      visitors: dynamic([e], selected_as(fragment(@uniq_users_expression, e.user_id), :visitors))
    }
  end

  on_full_build do
    defp select_event_metric(:total_revenue) do
      %{total_revenue: Plausible.Stats.Goal.Revenue.total_revenue_query()}
    end

    defp select_event_metric(:average_revenue) do
      %{average_revenue: Plausible.Stats.Goal.Revenue.average_revenue_query()}
    end
  end

  defp select_event_metric(:sample_percent) do
    %{
      sample_percent:
        dynamic(
          [],
          fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
        )
    }
  end

  defp select_event_metric(:percentage), do: %{}
  defp select_event_metric(:conversion_rate), do: %{}
  defp select_event_metric(:total_visitors), do: %{}

  defp select_event_metric(unknown), do: raise("Unknown metric: #{unknown}")

  def select_session_metrics(metrics, query) do
    metrics
    |> Enum.map(&select_session_metric(&1, query))
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp select_session_metric(:bounce_rate, query) do
    condition = dynamic_filter_condition(query, "event:page", :entry_page)

    %{
      bounce_rate:
        dynamic(
          [],
          fragment(
            "toUInt32(ifNotFinite(round(sumIf(is_bounce * sign, ?) / sumIf(sign, ?) * 100), 0))",
            ^condition,
            ^condition
          )
        ),
      __internal_visits: dynamic([], fragment("toUInt32(sum(sign))"))
    }
  end

  defp select_session_metric(:visits, _query) do
    %{
      visits: dynamic([s], fragment("toUInt64(round(sum(?) * any(_sample_factor)))", s.sign))
    }
  end

  defp select_session_metric(:pageviews, _query) do
    %{
      pageviews:
        dynamic(
          [s],
          fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.pageviews)
        )
    }
  end

  defp select_session_metric(:events, _query) do
    %{
      events:
        dynamic(
          [s],
          fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.events)
        )
    }
  end

  defp select_session_metric(:visitors, _query) do
    %{
      visitors:
        dynamic(
          [s],
          selected_as(
            fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id),
            :visitors
          )
        )
    }
  end

  defp select_session_metric(:visit_duration, _query) do
    %{
      visit_duration:
        dynamic([], fragment("toUInt32(ifNotFinite(round(sum(duration * sign) / sum(sign)), 0))")),
      __internal_visits: dynamic([], fragment("toUInt32(sum(sign))"))
    }
  end

  defp select_session_metric(:views_per_visit, _query) do
    %{
      views_per_visit:
        dynamic(
          [s],
          fragment("ifNotFinite(round(sum(? * ?) / sum(?), 2), 0)", s.sign, s.pageviews, s.sign)
        ),
      __internal_visits: dynamic([], fragment("toUInt32(sum(sign))"))
    }
  end

  defp select_session_metric(:sample_percent, _query) do
    %{
      sample_percent:
        dynamic(
          [],
          fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
        )
    }
  end

  defp select_session_metric(:percentage, _query), do: %{}

  def dynamic_filter_condition(query, filter_key, db_field) do
    case query && query.filters && query.filters[filter_key] do
      {:is, value} ->
        value = db_field_val(db_field, value)
        dynamic([x], field(x, ^db_field) == ^value)

      {:is_not, value} ->
        value = db_field_val(db_field, value)
        dynamic([x], field(x, ^db_field) != ^value)

      {:matches_member, glob_exprs} ->
        page_regexes = Enum.map(glob_exprs, &page_regex/1)
        dynamic([x], fragment("multiMatchAny(?, ?)", field(x, ^db_field), ^page_regexes))

      {:not_matches_member, glob_exprs} ->
        page_regexes = Enum.map(glob_exprs, &page_regex/1)
        dynamic([x], fragment("not(multiMatchAny(?, ?))", field(x, ^db_field), ^page_regexes))

      {:matches, glob_expr} ->
        regex = page_regex(glob_expr)
        dynamic([x], fragment("match(?, ?)", field(x, ^db_field), ^regex))

      {:does_not_match, glob_expr} ->
        regex = page_regex(glob_expr)
        dynamic([x], fragment("not(match(?, ?))", field(x, ^db_field), ^regex))

      {:member, list} ->
        list = Enum.map(list, &db_field_val(db_field, &1))
        dynamic([x], field(x, ^db_field) in ^list)

      {:not_member, list} ->
        list = Enum.map(list, &db_field_val(db_field, &1))
        dynamic([x], field(x, ^db_field) not in ^list)

      nil ->
        true
    end
  end

  def filter_converted_sessions(db_query, site, query) do
    if Query.has_event_filters?(query) do
      converted_sessions =
        from(e in query_events(site, query),
          select: %{
            session_id: fragment("DISTINCT ?", e.session_id),
            _sample_factor: fragment("_sample_factor")
          }
        )

      from(s in db_query,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id
      )
    else
      db_query
    end
  end

  defp db_field_val(:referrer_source, @no_ref), do: ""
  defp db_field_val(:referrer, @no_ref), do: ""
  defp db_field_val(:utm_medium, @no_ref), do: ""
  defp db_field_val(:utm_source, @no_ref), do: ""
  defp db_field_val(:utm_campaign, @no_ref), do: ""
  defp db_field_val(:utm_content, @no_ref), do: ""
  defp db_field_val(:utm_term, @no_ref), do: ""
  defp db_field_val(_, @not_set), do: ""
  defp db_field_val(_, val), do: val

  defp beginning_of_time(candidate, native_stats_start_at) do
    if Timex.after?(native_stats_start_at, candidate) do
      native_stats_start_at
    else
      candidate
    end
  end

  def utc_boundaries(%Query{period: "realtime", now: now}, site) do
    last_datetime =
      now
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      now |> Timex.shift(minutes: -5) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{period: "30m", now: now}, site) do
    last_datetime =
      now
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      now |> Timex.shift(minutes: -30) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{date_range: date_range}, site) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      first
      |> Timezones.to_utc_datetime(site.timezone)
      |> beginning_of_time(site.native_stats_start_at)

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime = Timezones.to_utc_datetime(last, site.timezone)

    {first_datetime, last_datetime}
  end

  def page_regex(expr) do
    escaped =
      expr
      |> Regex.escape()
      |> String.replace("\\|", "|")
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^#{escaped}$"
  end

  defp split_goals(clauses, map_fn \\ &Function.identity/1) do
    groups =
      Enum.group_by(clauses, fn {goal_type, _v} -> goal_type end, fn {_k, val} -> map_fn.(val) end)

    {
      Map.get(groups, :event, []),
      Map.get(groups, :page, [])
    }
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:is, "(none)"}}, q) do
    from(
      e in q,
      where: not has_key(e, :meta, ^prop_name)
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:is, value}}, q) do
    from(
      e in q,
      where: has_key(e, :meta, ^prop_name) and get_by_key(e, :meta, ^prop_name) == ^value
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:is_not, "(none)"}}, q) do
    from(
      e in q,
      where: has_key(e, :meta, ^prop_name)
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:is_not, value}}, q) do
    from(
      e in q,
      where: not has_key(e, :meta, ^prop_name) or get_by_key(e, :meta, ^prop_name) != ^value
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:matches, value}}, q) do
    regex = page_regex(value)

    from(
      e in q,
      where:
        has_key(e, :meta, ^prop_name) and
          fragment("match(?, ?)", get_by_key(e, :meta, ^prop_name), ^regex)
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:member, values}}, q) do
    none_value_included = Enum.member?(values, "(none)")

    from(
      e in q,
      where:
        (has_key(e, :meta, ^prop_name) and get_by_key(e, :meta, ^prop_name) in ^values) or
          (^none_value_included and not has_key(e, :meta, ^prop_name))
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:not_member, values}}, q) do
    none_value_included = Enum.member?(values, "(none)")

    from(
      e in q,
      where:
        (has_key(e, :meta, ^prop_name) and
           get_by_key(e, :meta, ^prop_name) not in ^values) or
          (^none_value_included and
             has_key(e, :meta, ^prop_name) and
             get_by_key(e, :meta, ^prop_name) not in ^values) or
          (not (^none_value_included) and not has_key(e, :meta, ^prop_name))
    )
  end

  defp filter_by_custom_prop({"event:props:" <> prop_name, {:matches_member, clauses}}, q) do
    regexes = Enum.map(clauses, &page_regex/1)

    from(
      e in q,
      where:
        has_key(e, :meta, ^prop_name) and
          fragment("arrayExists(k -> match(?, k), ?)", get_by_key(e, :meta, ^prop_name), ^regexes)
    )
  end

  defp total_visitors(site, query) do
    base_event_query(site, query)
    |> select([e], total_visitors: fragment(@uniq_users_expression, e.user_id))
  end

  defp total_visitors_subquery(site, query, true) do
    dynamic(
      [e],
      selected_as(
        subquery(total_visitors(site, query)) +
          subquery(Plausible.Stats.Imported.total_imported_visitors(site, query)),
        :__total_visitors
      )
    )
  end

  defp total_visitors_subquery(site, query, false) do
    dynamic([e], selected_as(subquery(total_visitors(site, query)), :__total_visitors))
  end

  def add_percentage_metric(q, site, query, metrics) do
    if :percentage in metrics do
      q
      |> select_merge(
        ^%{__total_visitors: total_visitors_subquery(site, query, query.include_imported)}
      )
      |> select_merge(%{
        percentage:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), null)",
            selected_as(:__total_visitors),
            selected_as(:visitors),
            selected_as(:__total_visitors)
          )
      })
    else
      q
    end
  end

  # Adds conversion_rate metric to query, calculated as
  # X / Y where Y is the same breakdown value without goal or props
  # filters.
  def maybe_add_conversion_rate(q, site, query, metrics, opts) do
    if :conversion_rate in metrics do
      include_imported = Keyword.fetch!(opts, :include_imported)

      total_query = query |> Query.remove_event_filters([:goal, :props])

      # :TRICKY: Subquery is used due to event:goal breakdown above doing an UNION ALL
      subquery(q)
      |> select_merge(
        ^%{total_visitors: total_visitors_subquery(site, total_query, include_imported)}
      )
      |> select_merge([e], %{
        conversion_rate:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), 0)",
            selected_as(:__total_visitors),
            e.visitors,
            selected_as(:__total_visitors)
          )
      })
    else
      q
    end
  end
end
