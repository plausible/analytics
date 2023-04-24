defmodule Plausible.Stats.Base do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, Filters}
  import Ecto.Query

  # Ecto typespec has not been updated for this PR: https://github.com/elixir-ecto/ecto/pull/3592
  @dialyzer {:nowarn_function, add_sample_hint: 2}
  @no_ref "Direct / None"
  @not_set "(not set)"

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

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def query_events(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    q =
      from(
        e in "events_v2",
        where: e.site_id == ^site.id,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )
      |> add_sample_hint(query)

    q =
      case query.filters["event:page"] do
        {:is, page} ->
          from(e in q, where: e.pathname == ^page)

        {:is_not, page} ->
          from(e in q, where: e.pathname != ^page)

        {:matches_member, glob_exprs} ->
          page_regexes = Enum.map(glob_exprs, &page_regex/1)
          from(e in q, where: fragment("multiMatchAny(?, ?)", e.pathname, ^page_regexes))

        {:not_matches_member, glob_exprs} ->
          page_regexes = Enum.map(glob_exprs, &page_regex/1)

          from(e in q,
            where: fragment("not(multiMatchAny(?, ?))", e.pathname, ^page_regexes)
          )

        {:matches, glob_expr} ->
          regex = page_regex(glob_expr)
          from(e in q, where: fragment("match(?, ?)", e.pathname, ^regex))

        {:does_not_match, glob_expr} ->
          regex = page_regex(glob_expr)
          from(e in q, where: fragment("not(match(?, ?))", e.pathname, ^regex))

        {:member, list} ->
          from(e in q, where: e.pathname in ^list)

        {:not_member, list} ->
          from(e in q, where: e.pathname not in ^list)

        nil ->
          q
      end

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
          from(e in q, where: e.pathname == ^path)

        {:matches, {:page, expr}} ->
          regex = page_regex(expr)
          from(e in q, where: fragment("match(?, ?)", e.pathname, ^regex))

        {:is, {:event, event}} ->
          from(e in q, where: e.name == ^event)

        {:member, clauses} ->
          {events, pages} = split_goals(clauses)
          from(e in q, where: e.pathname in ^pages or e.name in ^events)

        {:matches_member, clauses} ->
          {events, pages} = split_goals(clauses, &page_regex/1)

          from(e in q,
            where:
              fragment("multiMatchAny(?, ?)", e.pathname, ^pages) or
                fragment("multiMatchAny(?, ?)", e.name, ^events)
          )

        {:not_matches_member, clauses} ->
          {events, pages} = split_goals(clauses, &page_regex/1)

          from(e in q,
            where:
              fragment("not(multiMatchAny(?, ?))", e.pathname, ^pages) and
                fragment("not(multiMatchAny(?, ?))", e.name, ^events)
          )

        {:not_member, clauses} ->
          {events, pages} = split_goals(clauses)
          from(e in q, where: e.pathname not in ^pages and e.name not in ^events)

        nil ->
          q
      end

    q =
      case Query.get_filter_by_prefix(query, "event:props") do
        {"event:props:" <> prop_name, {:is, value}} ->
          if value == "(none)" do
            from(
              e in q,
              where: fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name)
            )
          else
            from(
              e in q,
              inner_lateral_join: meta in "meta",
              as: :meta,
              where: meta.key == ^prop_name and meta.value == ^value
            )
          end

        {"event:props:" <> prop_name, {:is_not, value}} ->
          if value == "(none)" do
            from(
              e in q,
              where: fragment("has(?, ?)", field(e, :"meta.key"), ^prop_name)
            )
          else
            from(
              e in q,
              left_lateral_join: meta in "meta",
              as: :meta,
              where:
                (meta.key == ^prop_name and meta.value != ^value) or
                  fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name)
            )
          end

        _ ->
          q
      end

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

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def query_sessions(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    sessions_q =
      from(
        s in "sessions_v2",
        where: s.site_id == ^site.id,
        where: s.start >= ^first_datetime and s.start < ^last_datetime
      )
      |> add_sample_hint(query)
      |> filter_by_entry_props(query)

    Enum.reduce(Filters.visit_props(), sessions_q, fn prop_name, sessions_q ->
      filter = query.filters["visit:" <> prop_name]

      prop_name =
        Map.get(@api_prop_name_to_db, prop_name, prop_name)
        |> String.to_existing_atom()

      case filter do
        {:is, value} ->
          value = db_prop_val(prop_name, value)
          from(s in sessions_q, where: fragment("? = ?", field(s, ^prop_name), ^value))

        {:is_not, value} ->
          value = db_prop_val(prop_name, value)
          from(s in sessions_q, where: fragment("? != ?", field(s, ^prop_name), ^value))

        {:member, values} ->
          list = Enum.map(values, &db_prop_val(prop_name, &1))
          from(s in sessions_q, where: field(s, ^prop_name) in ^list)

        {:not_member, values} ->
          list = Enum.map(values, &db_prop_val(prop_name, &1))
          from(s in sessions_q, where: fragment("? not in ?", field(s, ^prop_name), ^list))

        {:matches, expr} ->
          regex = page_regex(expr)
          from(s in sessions_q, where: fragment("match(?, ?)", field(s, ^prop_name), ^regex))

        {:matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)

          from(s in sessions_q,
            where: fragment("multiMatchAny(?, ?)", field(s, ^prop_name), ^page_regexes)
          )

        {:not_matches_member, exprs} ->
          page_regexes = Enum.map(exprs, &page_regex/1)

          from(s in sessions_q,
            where: fragment("not(multiMatchAny(?, ?))", field(s, ^prop_name), ^page_regexes)
          )

        {:does_not_match, expr} ->
          regex = page_regex(expr)
          from(s in sessions_q, where: fragment("not(match(?, ?))", field(s, ^prop_name), ^regex))

        nil ->
          sessions_q

        _ ->
          raise "Unknown filter type"
      end
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
      where: fragment("not has(?, ?)", field(s, :"entry_meta.key"), ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is, value}) do
    from(
      s in sessions_q,
      inner_lateral_join: meta in "entry_meta",
      as: :meta,
      where: meta.key == ^prop_name and meta.value == ^value
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is_not, "(none)"}) do
    from(
      s in sessions_q,
      where: fragment("has(?, ?)", field(s, :"entry_meta.key"), ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is_not, value}) do
    from(
      s in sessions_q,
      left_lateral_join: meta in "entry_meta",
      as: :meta,
      where:
        (meta.key == ^prop_name and meta.value != ^value) or
          fragment("not has(?, ?)", field(s, :"entry_meta.key"), ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, _, _), do: sessions_q

  def select_event_metrics(q, []), do: q

  def select_event_metrics(q, [:pageviews | rest]) do
    from(e in q,
      select_merge: %{
        pageviews:
          fragment("toUInt64(round(countIf(? = 'pageview') * any(_sample_factor)))", e.name)
      }
    )
    |> select_event_metrics(rest)
  end

  def select_event_metrics(q, [:events | rest]) do
    from(e in q,
      select_merge: %{events: fragment("toUInt64(round(count(*) * any(_sample_factor)))")}
    )
    |> select_event_metrics(rest)
  end

  def select_event_metrics(q, [:visitors | rest]) do
    from(e in q,
      select_merge: %{
        visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.user_id)
      }
    )
    |> select_event_metrics(rest)
  end

  def select_event_metrics(q, [:sample_percent | rest]) do
    from(e in q,
      select_merge: %{
        sample_percent:
          fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
      }
    )
    |> select_event_metrics(rest)
  end

  def select_event_metrics(_, [unknown | _]), do: raise("Unknown metric " <> unknown)

  def select_session_metrics(q, []), do: q

  def select_session_metrics(q, [:bounce_rate | rest]) do
    from(s in q,
      select_merge: %{
        bounce_rate:
          fragment("toUInt32(ifNotFinite(round(sum(is_bounce * sign) / sum(sign) * 100), 0))"),
        __internal_visits: fragment("toUInt32(sum(sign))")
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:visits | rest]) do
    from(s in q,
      select_merge: %{
        visits: fragment("toUInt64(round(sum(?) * any(_sample_factor)))", s.sign)
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:pageviews | rest]) do
    from(s in q,
      select_merge: %{
        pageviews:
          fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.pageviews)
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:events | rest]) do
    from(s in q,
      select_merge: %{
        events: fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.events)
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:visitors | rest]) do
    from(s in q,
      select_merge: %{
        visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id)
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:visit_duration | rest]) do
    from(s in q,
      select_merge: %{
        :visit_duration =>
          fragment("toUInt32(ifNotFinite(round(sum(duration * sign) / sum(sign)), 0))"),
        __internal_visits: fragment("toUInt32(sum(sign))")
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:views_per_visit | rest]) do
    from(s in q,
      select_merge: %{
        views_per_visit:
          fragment("ifNotFinite(round(sum(? * ?) / sum(?), 2), 0)", s.sign, s.pageviews, s.sign)
      }
    )
    |> select_session_metrics(rest)
  end

  def select_session_metrics(q, [:sample_percent | rest]) do
    from(e in q,
      select_merge: %{
        sample_percent:
          fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
      }
    )
    |> select_event_metrics(rest)
  end

  def filter_converted_sessions(db_query, site, query) do
    if Query.has_event_filters?(query) do
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

  defp db_prop_val(:referrer_source, @no_ref), do: ""
  defp db_prop_val(:referrer, @no_ref), do: ""
  defp db_prop_val(:utm_medium, @no_ref), do: ""
  defp db_prop_val(:utm_source, @no_ref), do: ""
  defp db_prop_val(:utm_campaign, @no_ref), do: ""
  defp db_prop_val(:utm_content, @no_ref), do: ""
  defp db_prop_val(:utm_term, @no_ref), do: ""
  defp db_prop_val(_, @not_set), do: ""
  defp db_prop_val(_, val), do: val

  defp beginning_of_time(candidate, native_stats_start_at) do
    if Timex.after?(native_stats_start_at, candidate) do
      native_stats_start_at
    else
      candidate
    end
  end

  def utc_boundaries(%Query{period: "realtime"}, site) do
    last_datetime =
      NaiveDateTime.utc_now()
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      NaiveDateTime.utc_now() |> Timex.shift(minutes: -5) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{period: "30m"}, site) do
    last_datetime =
      NaiveDateTime.utc_now()
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      NaiveDateTime.utc_now() |> Timex.shift(minutes: -30) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{date_range: date_range}, site) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      Timex.to_datetime(first, site.timezone)
      |> Timex.Timezone.convert("UTC")
      |> beginning_of_time(site.native_stats_start_at)

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime =
      Timex.to_datetime(last, site.timezone)
      |> Timex.Timezone.convert("UTC")

    {first_datetime, last_datetime}
  end

  @replaces %{
    ~r/\*\*/ => ".*",
    ~r/(?<!\.)\*/ => "[^/]*",
    "(" => "\\(",
    ")" => "\\)"
  }
  def page_regex(expr) do
    Enum.reduce(@replaces, "^#{expr}$", fn {pattern, replacement}, regex ->
      String.replace(regex, pattern, replacement)
    end)
  end

  defp add_sample_hint(db_q, query) do
    case query.sample_threshold do
      "infinite" ->
        db_q

      threshold ->
        from(e in db_q, hints: [sample: threshold])
    end
  end

  defp split_goals(clauses, map_fn \\ &Function.identity/1) do
    groups =
      Enum.group_by(clauses, fn {goal_type, _v} -> goal_type end, fn {_k, val} -> map_fn.(val) end)

    {
      Map.get(groups, :event, []),
      Map.get(groups, :page, [])
    }
  end
end
