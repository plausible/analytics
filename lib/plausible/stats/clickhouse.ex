defmodule Plausible.Stats.Clickhouse do
  use Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Clickhouse
  @no_ref "Direct / None"

  def compare_pageviews_and_visitors(site, query, {pageviews, visitors}) do
    query = Query.shift_back(query)
    {old_pageviews, old_visitors} = pageviews_and_visitors(site, query)

    cond do
      old_pageviews == 0 and pageviews > 0 ->
        {100, 100}

      old_pageviews == 0 and pageviews == 0 ->
        {0, 0}

      true ->
        {
          round((pageviews - old_pageviews) / old_pageviews * 100),
          round((visitors - old_visitors) / old_visitors * 100)
        }
    end
  end

  def calculate_plot(site, %Query{step_type: "month"} = query) do
    steps =
      Enum.map((query.steps - 1)..0, fn shift ->
        Timex.now(site.timezone)
        |> Timex.beginning_of_month()
        |> Timex.shift(months: -shift)
        |> DateTime.to_date()
      end)

    groups =
      Clickhouse.all(
        from e in base_query(site, query),
          select:
            {fragment("toStartOfMonth(toTimeZone(?, ?)) as month", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("month"),
          order_by: fragment("month")
      )
      |> Enum.map(fn row -> {row["month"], row["visitors"]} end)
      |> Enum.into(%{})

    present_index =
      Enum.find_index(steps, fn step ->
        step == Timex.now(site.timezone) |> Timex.to_date() |> Timex.beginning_of_month()
      end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups =
      Clickhouse.all(
        from e in base_query(site, query),
          select:
            {fragment("toDate(toTimeZone(?, ?)) as day", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("day"),
          order_by: fragment("day")
      )
      |> Enum.map(fn row -> {row["day"], row["visitors"]} end)
      |> Enum.into(%{})

    present_index =
      Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date() end)

    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "hour"} = query) do
    steps = 0..23

    groups =
      Clickhouse.all(
        from e in base_query(site, query),
          select:
            {fragment("toHour(toTimeZone(?, ?)) as hour", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("hour"),
          order_by: fragment("hour")
      )
      |> Enum.map(fn row -> {row["hour"], row["visitors"]} end)
      |> Enum.into(%{})

    now = Timex.now(site.timezone)
    is_today = Timex.to_date(now) == query.date_range.first
    present_index = is_today && Enum.find_index(steps, fn step -> step == now.hour end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)

    labels =
      Enum.map(steps, fn step ->
        Timex.to_datetime(query.date_range.first)
        |> Timex.shift(hours: step)
        |> NaiveDateTime.to_iso8601()
      end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{period: "realtime"} = query) do
    query = %Query{query | period: "30m"}

    groups =
      Clickhouse.all(
        from e in base_query(site, query),
          select: {
            fragment("dateDiff('minute', now(), ?) as relativeMinute", e.timestamp),
            fragment("count(*) as pageviews")
          },
          group_by: fragment("relativeMinute"),
          order_by: fragment("relativeMinute")
      )
      |> Enum.map(fn row -> {row["relativeMinute"], row["pageviews"]} end)
      |> Enum.into(%{})

    labels = Enum.into(-30..-1, [])
    plot = Enum.map(labels, fn label -> groups[label] || 0 end)
    {plot, labels, nil}
  end

  def bounce_rate(site, query) do
    [res] =
      Clickhouse.all(
        from s in base_session_query(site, query),
          select: {fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")}
      )

    res["bounce_rate"] || 0
  end

  def visit_duration(site, query) do
    [res] =
      Clickhouse.all(
        from s in base_session_query(site, query),
          select: {fragment("round(avg(duration * sign)) as visit_duration")}
      )

    res["visit_duration"] || 0
  end

  def total_pageviews(site, %Query{period: "realtime"} = query) do
    query = %Query{query | period: "30m"}

    [res] =
      Clickhouse.all(
        from e in base_session_query(site, query),
          select: fragment("sum(sign * pageviews) as pageviews")
      )

    res["pageviews"]
  end

  def total_events(site, query) do
    [res] =
      Clickhouse.all(
        from e in base_query(site, query),
          select: fragment("count(*) as events")
      )

    res["events"]
  end

  def pageviews_and_visitors(site, query) do
    [res] =
      Clickhouse.all(
        from e in base_query_w_sessions(site, query),
          select:
            {fragment("count(*) as pageviews"),
             fragment("uniq(user_id) as visitors")}
      )

    {res["pageviews"], res["visitors"]}
  end

  def unique_visitors(site, query) do
    [res] =
      Clickhouse.all(
        from e in base_query(site, query),
          select: fragment("uniq(user_id) as visitors")
      )

    res["visitors"]
  end

  def top_referrers_for_goal(site, query, limit \\ 5) do
    converted_sessions =
      from(
        from e in base_query(site, query),
          select: %{session_id: e.session_id}
      )

    Plausible.Clickhouse.all(
      from s in Plausible.ClickhouseSession,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id,
        select:
          {fragment("? as name", s.referrer_source), fragment("any(?) as url", s.referrer),
           fragment("uniq(user_id) as count")},
        where: s.referrer_source != "",
        group_by: s.referrer_source,
        order_by: [desc: fragment("count")],
        limit: ^limit
    )
    |> Enum.map(fn ref ->
      Map.update(ref, "url", nil, fn url -> url && URI.parse("http://" <> url).host end)
    end)
  end

  def top_referrers(site, query, limit \\ 5, show_noref \\ false, include \\ []) do
    referrers =
      from(s in base_session_query(site, query),
        group_by: s.referrer_source,
        order_by: [desc: fragment("count")],
        limit: ^limit
      )

    referrers = if show_noref do
      referrers
    else
      from(s in referrers, where: s.referrer_source != "")
    end

    referrers = if query.filters["page"] do
      page = query.filters["page"]
      from(s in referrers, where: s.entry_page == ^page)
    else
      referrers
    end

    referrers =
      if "bounce_rate" in include do
        from(
          s in referrers,
          select:
            {fragment("if(empty(?), ?, ?) as name", s.referrer_source, @no_ref, s.referrer_source), fragment("any(?) as url", s.referrer),
             fragment("uniq(user_id) as count"),
             fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate"),
             fragment("round(avg(duration * sign)) as visit_duration")}
        )
      else
        from(
          s in referrers,
          select:
            {fragment("if(empty(?), ?, ?) as name", s.referrer_source, @no_ref, s.referrer_source), fragment("any(?) as url", s.referrer),
             fragment("uniq(user_id) as count")}
        )
      end

      Clickhouse.all(referrers)
      |> Enum.map(fn ref ->
        Map.update(ref, "url", nil, fn url -> url && URI.parse("http://" <> url).host end)
      end)
  end

  def conversions_from_referrer(site, query, referrer) do
    converted_sessions =
      from(
        from e in base_query(site, query),
          select: %{session_id: e.session_id}
      )

    [res] =
      Plausible.Clickhouse.all(
        from s in Plausible.ClickhouseSession,
          join: cs in subquery(converted_sessions),
          on: s.session_id == cs.session_id,
          where: s.referrer_source == ^referrer,
          select: fragment("uniq(user_id) as visitors")
      )

    res["visitors"]
  end

  def referrer_drilldown(site, query, referrer, include, limit) do
    referrer = if referrer == @no_ref, do: "", else: referrer

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.referrer,
        where: s.referrer_source == ^referrer,
        order_by: [desc: fragment("count")],
        limit: ^limit
      )

    q =
      if "bounce_rate" in include do
        from(
          s in q,
          select:
          {fragment("if(empty(?), ?, ?) as name", s.referrer, @no_ref, s.referrer),
            fragment("uniq(user_id) as count"),
             fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate"),
             fragment("round(avg(duration * sign)) as visit_duration")}
        )
      else
        from(s in q,
          select: {fragment("if(empty(?), ?, ?) as name", s.referrer, @no_ref, s.referrer), fragment("uniq(user_id) as count")}
        )
      end

    referring_urls =
      Clickhouse.all(q)
      |> Enum.map(fn ref ->
        url = if ref["name"] !== "", do: URI.parse("http://" <> ref["name"]).host
        Map.put(ref, "url", url)
      end)

    if referrer == "Twitter" do
      urls = Enum.map(referring_urls, & &1["name"])

      tweets =
        Repo.all(
          from t in Plausible.Twitter.Tweet,
            where: t.link in ^urls
        )
        |> Enum.group_by(& &1.link)

      Enum.map(referring_urls, fn url ->
        Map.put(url, "tweets", tweets[url["name"]])
      end)
    else
      referring_urls
    end
  end

  def referrer_drilldown_for_goal(site, query, referrer) do
    converted_sessions =
      from(
        from e in base_query(site, query),
          select: %{session_id: e.session_id}
      )

    Plausible.Clickhouse.all(
      from s in Plausible.ClickhouseSession,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id,
        select: {fragment("? as name", s.referrer), fragment("uniq(user_id) as count")},
        where: s.referrer_source == ^referrer,
        group_by: s.referrer,
        order_by: [desc: fragment("count")],
        limit: 100
    )
  end

  def entry_pages(site, query, limit, include) do
    q = from(
      s in base_session_query(site, query),
      group_by: s.entry_page,
      order_by: [desc: fragment("count")],
      limit: ^limit,
      select:
      {fragment("? as name", s.entry_page), fragment("uniq(?) as count", s.user_id)}
    )

    q = if query.filters["page"] do
      page = query.filters["page"]
      from(s in q, where: s.entry_page == ^page)
    else
      q
    end

    pages = Clickhouse.all(q)

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_page_url(site, query)
      Enum.map(pages, fn url -> Map.put(url, "bounce_rate", bounce_rates[url["name"]]) end)
    else
      pages
    end
  end

  def top_pages(site, %Query{period: "realtime"} = query, limit, _include) do
    Clickhouse.all(
      from s in base_session_query(site, query),
        select: {fragment("? as name", s.exit_page), fragment("uniq(?) as count", s.user_id)},
        group_by: s.exit_page,
        order_by: [desc: fragment("count")],
        limit: ^limit
    )
  end

  def top_pages(site, query, limit, include) do
    q =
      from(
        e in base_query(site, query),
        group_by: e.pathname,
        order_by: [desc: fragment("count")],
        limit: ^limit,
        select:
        {fragment("? as name", e.pathname), fragment("uniq(?) as count", e.user_id),
          fragment("count(*) as pageviews")}
      )

    pages = Clickhouse.all(q)

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_page_url(site, query)
      Enum.map(pages, fn url -> Map.put(url, "bounce_rate", bounce_rates[url["name"]]) end)
    else
      pages
    end
  end

  defp bounce_rates_by_page_url(site, query) do
    Clickhouse.all(
      from s in base_session_query(site, query),
        select:
          {s.entry_page, fragment("count(*) as total"),
           fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")},
        group_by: s.entry_page,
        order_by: [desc: fragment("total")],
        limit: 100
    )
    |> Enum.map(fn row -> {row["entry_page"], row["bounce_rate"]} end)
    |> Enum.into(%{})
  end

  defp add_percentages(stat_list) do
    total = Enum.reduce(stat_list, 0, fn %{"count" => count}, total -> total + count end)

    Enum.map(stat_list, fn stat ->
      Map.put(stat, "percentage", round(stat["count"] / total * 100))
    end)
  end

  def top_screen_sizes(site, query) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {fragment("? as name", e.screen_size), fragment("uniq(user_id) as count")},
        group_by: e.screen_size,
        where: e.screen_size != "",
        order_by: [desc: fragment("count")]
    )
    |> add_percentages
  end

  def countries(site, query) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {fragment("? as name", e.country_code), fragment("uniq(user_id) as count")},
        group_by: e.country_code,
        where: e.country_code != "\0\0",
        order_by: [desc: fragment("count")]
    )
    |> Enum.map(fn stat ->
      two_letter_code = stat["name"]

      stat
      |> Map.put("name", Plausible.Stats.CountryName.to_alpha3(two_letter_code))
      |> Map.put("full_country_name", Plausible.Stats.CountryName.from_iso3166(two_letter_code))
    end)
    |> add_percentages
  end

  def browsers(site, query, limit \\ 5) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {fragment("? as name", e.browser), fragment("uniq(user_id) as count")},
        group_by: e.browser,
        where: e.browser != "",
        order_by: [desc: fragment("count")]
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def operating_systems(site, query, limit \\ 5) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {fragment("? as name", e.operating_system), fragment("uniq(user_id) as count")},
        group_by: e.operating_system,
        where: e.operating_system != "",
        order_by: [desc: fragment("count")]
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def current_visitors(site, query) do
    [res] =
      Clickhouse.all(
        from s in base_query(site, query),
          select: fragment("uniq(user_id) as visitors")
      )

    res["visitors"]
  end

  def has_pageviews?([]), do: false

  def has_pageviews?(domains) when is_list(domains) do
    res =
      Clickhouse.all(
        from e in "events",
          select: e.timestamp,
          where: fragment("? IN tuple(?)", e.domain, ^domains),
          limit: 1
      )

    !Enum.empty?(res)
  end

  def has_pageviews?(site) do
    res =
      Clickhouse.all(
        from e in "events",
          select: e.timestamp,
          where: e.domain == ^site.domain,
          limit: 1
      )

    !Enum.empty?(res)
  end

  def goal_conversions(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {e.name, fragment("uniq(user_id) as count")},
        group_by: e.name,
        order_by: [desc: fragment("count")]
    )
    |> Enum.map(fn row -> %{"name" => goal, "count" => row["count"]} end)
  end

  def goal_conversions(site, query) do
    goals = Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    query = if query.period == "realtime", do: %Query{query | period: "30m"}, else: query

    (fetch_pageview_goals(goals, site, query) ++
       fetch_event_goals(goals, site, query))
    |> sort_conversions()
  end

  defp fetch_event_goals(goals, site, query) do
    events =
      Enum.map(goals, fn goal -> goal.event_name end)
      |> Enum.filter(& &1)

    if Enum.count(events) > 0 do
      {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

      q =
        from(
          e in "events",
          where: e.domain == ^site.domain,
          where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime,
          where: fragment("? IN tuple(?)", e.name, ^events),
          select: {e.name, fragment("uniq(user_id) as count")},
          group_by: e.name
        )

      q =
        if query.filters["source"] do
          filtered_sessions =
            from(s in base_session_query(site, query), select: %{session_id: s.session_id})

          from(
            e in q,
            join: cs in subquery(filtered_sessions),
            on: e.session_id == cs.session_id
          )
        else
          q
        end

      q =
        if query.filters["page"] do
          page = query.filters["page"]
          from(e in q, where: e.pathname == ^page)
        else
          q
        end

      Clickhouse.all(q)
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query) do
    pages =
      Enum.map(goals, fn goal -> goal.page_path end)
      |> Enum.filter(& &1)

    if Enum.count(pages) > 0 do
      {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

      q =
        from(
          e in "events",
          where: e.domain == ^site.domain,
          where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime,
          where: fragment("? IN tuple(?)", e.pathname, ^pages),
          group_by: e.pathname,
          select:
            {fragment("concat('Visit ', ?) as name", e.pathname),
             fragment("uniq(user_id) as count")}
        )

      q =
        if query.filters["source"] do
          filtered_sessions =
            from(s in base_session_query(site, query), select: %{session_id: s.session_id})

          from(
            e in q,
            join: cs in subquery(filtered_sessions),
            on: e.session_id == cs.session_id
          )
        else
          q
        end

      q =
        if query.filters["page"] do
          page = query.filters["page"]
          from(e in q, where: e.pathname == ^page)
        else
          q
        end

      Clickhouse.all(q)
    else
      []
    end
  end

  defp sort_conversions(conversions) do
    Enum.sort_by(conversions, fn conversion -> -conversion["count"] end)
  end

  defp base_query_w_sessions(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q = from(s in "sessions",
      where: s.domain == ^site.domain,
      where: s.timestamp >= ^first_datetime and s.start < ^last_datetime,
      select: %{session_id: s.session_id}
    )

    sessions_q =
      if query.filters["source"] do
        source = query.filters["source"]
        source = if source == @no_ref, do: "", else: source
        from(s in sessions_q, where: s.referrer_source == ^source)
      else
        sessions_q
      end

    sessions_q = if query.filters["referrer"] do
      ref = query.filters["referrer"]
      from(s in sessions_q, where: s.referrer == ^ref)
    else
      sessions_q
    end

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q = if query.filters["source"] || query.filters['referrer'] do
      from(
        e in q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      q
    end

    if query.filters["page"] do
      page = query.filters["page"]
      from(e in q, where: e.pathname == ^page)
    else
      q
    end
  end

  defp base_session_query(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    q =
      from(s in "sessions",
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      )

    q =
      if query.filters["source"] do
        source = query.filters["source"]
        source = if source == @no_ref, do: "", else: source
        from(s in q, where: s.referrer_source == ^source)
      else
        q
      end

    q =
      if query.filters["page"] do
        page = query.filters["page"]
        from(s in q, where: s.entry_page == ^page)
      else
        q
      end

    if query.filters["referrer"] do
      ref = query.filters["referrer"]
      from(e in q, where: e.referrer == ^ref)
    else
      q
    end
  end

  defp base_query(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)
    {goal_event, path} = event_name_for_goal(query)

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if query.filters["source"] do
        source = query.filters["source"]
        source = if source == @no_ref, do: "", else: source
        from(e in q, where: e.referrer_source == ^source)
      else
        q
      end

    q =
      if query.filters["referrer"] do
        ref = query.filters["referrer"]
        from(e in q, where: e.referrer == ^ref)
      else
        q
      end

    q =
      if query.filters["page"] do
        page = query.filters["page"]
        from(e in q, where: e.pathname == ^page)
      else
        q
      end

    q =
      if path do
        from(e in q, where: e.pathname == ^path)
      else
        q
      end

    if goal_event do
      from(e in q, where: e.name == ^goal_event)
    else
      from(e in q, where: e.name == "pageview")
    end
  end

  defp utc_boundaries(%Query{period: "30m"}, _timezone) do
    last_datetime = NaiveDateTime.utc_now()

    first_datetime = last_datetime |> Timex.shift(minutes: -30)
    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{period: "realtime"}, _timezone) do
    last_datetime = NaiveDateTime.utc_now()

    first_datetime = last_datetime |> Timex.shift(minutes: -5)
    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{date_range: date_range}, timezone) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      Timex.to_datetime(first, timezone)
      |> Timex.Timezone.convert("UTC")

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime =
      Timex.to_datetime(last, timezone)
      |> Timex.Timezone.convert("UTC")

    {first_datetime, last_datetime}
  end

  defp event_name_for_goal(query) do
    case query.filters["goal"] do
      "Visit " <> page ->
        {"pageview", page}

      goal when is_binary(goal) ->
        {goal, nil}

      _ ->
        {nil, nil}
    end
  end
end
