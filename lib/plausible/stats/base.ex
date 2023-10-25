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

    q = from(e in q, where: ^dynamic_filter_condition(query, "event:page", :pathname))

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

          event_clause =
            if Enum.any?(events) do
              dynamic([x], fragment("multiMatchAny(?, ?)", x.name, ^events))
            else
              dynamic([x], false)
            end

          page_clause =
            if Enum.any?(pages) do
              dynamic([x], fragment("multiMatchAny(?, ?)", x.pathname, ^pages))
            else
              dynamic([x], false)
            end

          where_clause = dynamic([], ^event_clause or ^page_clause)

          from(e in q, where: ^where_clause)

        {:not_matches_member, clauses} ->
          {events, pages} = split_goals(clauses, &page_regex/1)

          event_clause =
            if Enum.any?(events) do
              dynamic([x], fragment("multiMatchAny(?, ?)", x.name, ^events))
            else
              dynamic([x], false)
            end

          page_clause =
            if Enum.any?(pages) do
              dynamic([x], fragment("multiMatchAny(?, ?)", x.pathname, ^pages))
            else
              dynamic([x], false)
            end

          where_clause = dynamic([], not (^event_clause or ^page_clause))

          from(e in q, where: ^where_clause)

        {:not_member, clauses} ->
          {events, pages} = split_goals(clauses)
          from(e in q, where: e.pathname not in ^pages and e.name not in ^events)

        nil ->
          q
      end

    apply_event_props_filter(q, query)
  end

  def apply_event_props_filter(ecto_query, plausible_query) do
    case Query.get_filter_by_prefix(plausible_query, "event:props") do
      {"event:props:" <> prop_name, {:is, value}} ->
        if value == "(none)" do
          from(
            e in ecto_query,
            where: fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name)
          )
        else
          from(
            e in ecto_query,
            array_join: meta in "meta",
            as: :meta,
            where: meta.key == ^prop_name and meta.value == ^value
          )
        end

      {"event:props:" <> prop_name, {:is_not, value}} ->
        if value == "(none)" do
          from(
            e in ecto_query,
            where: fragment("has(?, ?)", field(e, :"meta.key"), ^prop_name)
          )
        else
          from(
            e in ecto_query,
            left_array_join: meta in "meta",
            as: :meta,
            where:
              (meta.key == ^prop_name and meta.value != ^value) or
                fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name)
          )
        end

      {"event:props:" <> prop_name, {:member, values}} ->
        none_value_included = Enum.member?(values, "(none)")

        from(
          e in ecto_query,
          left_array_join: meta in "meta",
          as: :meta,
          where:
            (meta.key == ^prop_name and meta.value in ^values) or
              (^none_value_included and
                 fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name))
        )

      {"event:props:" <> prop_name, {:not_member, values}} ->
        none_value_included = Enum.member?(values, "(none)")

        from(
          e in ecto_query,
          left_array_join: meta in "meta",
          as: :meta,
          where:
            (meta.key == ^prop_name and meta.value not in ^values) or
              (^none_value_included and fragment("has(?, ?)", field(e, :"meta.key"), ^prop_name) and
                 meta.value not in ^values) or
              (not (^none_value_included) and
                 fragment("not has(?, ?)", field(e, :"meta.key"), ^prop_name))
        )

      _ ->
        ecto_query
    end
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
      where: fragment("not has(?, ?)", field(s, :"entry_meta.key"), ^prop_name)
    )
  end

  def apply_entry_prop_filter(sessions_q, prop_name, {:is, value}) do
    from(
      s in sessions_q,
      array_join: meta in "entry_meta",
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
      left_array_join: meta in "entry_meta",
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

  def select_event_metrics(q, [:total_revenue | rest]) do
    from(e in q,
      select_merge: %{
        total_revenue:
          fragment("toDecimal64(sum(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
      }
    )
    |> select_event_metrics(rest)
  end

  def select_event_metrics(q, [:average_revenue | rest]) do
    from(e in q,
      select_merge: %{
        average_revenue:
          fragment("toDecimal64(avg(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
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

  def select_session_metrics(q, [], _query), do: q

  def select_session_metrics(q, [:bounce_rate | rest], query) do
    condition = dynamic_filter_condition(query, "event:page", :entry_page)

    from(s in q,
      select_merge:
        ^%{
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
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:visits | rest], query) do
    from(s in q,
      select_merge: %{
        visits: fragment("toUInt64(round(sum(?) * any(_sample_factor)))", s.sign)
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:pageviews | rest], query) do
    from(s in q,
      select_merge: %{
        pageviews:
          fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.pageviews)
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:events | rest], query) do
    from(s in q,
      select_merge: %{
        events: fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.events)
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:visitors | rest], query) do
    from(s in q,
      select_merge: %{
        visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id)
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:visit_duration | rest], query) do
    from(s in q,
      select_merge: %{
        :visit_duration =>
          fragment("toUInt32(ifNotFinite(round(sum(duration * sign) / sum(sign)), 0))"),
        __internal_visits: fragment("toUInt32(sum(sign))")
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:views_per_visit | rest], query) do
    from(s in q,
      select_merge: %{
        views_per_visit:
          fragment("ifNotFinite(round(sum(? * ?) / sum(?), 2), 0)", s.sign, s.pageviews, s.sign)
      }
    )
    |> select_session_metrics(rest, query)
  end

  def select_session_metrics(q, [:sample_percent | rest], query) do
    from(e in q,
      select_merge: %{
        sample_percent:
          fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
      }
    )
    |> select_session_metrics(rest, query)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
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
      :infinite ->
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
