defmodule Plausible.Stats.Clickhouse do
  use Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Clickhouse

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
        from e in base_query(site, %{query | filters: %{}}),
          select:
            {fragment("toStartOfMonth(toTimeZone(?, ?)) as month", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("month"),
          order_by: fragment("month")
      )
      |> Enum.map(fn row -> {row["month"], row["visitors"]} end)
      |> Enum.into(%{})

    compare_groups =
      if query.filters["goal"] do
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
      end

    present_index =
      Enum.find_index(steps, fn step ->
        step == Timex.now(site.timezone) |> Timex.to_date() |> Timex.beginning_of_month()
      end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, compare_plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups =
      Clickhouse.all(
        from e in base_query(site, %{query | filters: %{}}),
          select:
            {fragment("toDate(toTimeZone(?, ?)) as day", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("day"),
          order_by: fragment("day")
      )
      |> Enum.map(fn row -> {row["day"], row["visitors"]} end)
      |> Enum.into(%{})

    compare_groups =
      if query.filters["goal"] do
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
      end

    present_index =
      Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date() end)

    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, compare_plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "hour"} = query) do
    steps = 0..23

    groups =
      Clickhouse.all(
        from e in base_query(site, %{query | filters: %{}}),
          select:
            {fragment("toHour(toTimeZone(?, ?)) as hour", e.timestamp, ^site.timezone),
             fragment("uniq(?) as visitors", e.user_id)},
          group_by: fragment("hour"),
          order_by: fragment("hour")
      )
      |> Enum.map(fn row -> {row["hour"], row["visitors"]} end)
      |> Enum.into(%{})

    compare_groups =
      if query.filters["goal"] do
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
      end

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
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    {plot, compare_plot, labels, present_index}
  end

  def bounce_rate(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    [res] =
      Clickhouse.all(
        from s in "sessions",
          select: {fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")},
          where: s.domain == ^site.domain,
          where: s.start >= ^first_datetime and s.start < ^last_datetime
      )

    res["bounce_rate"] || 0
  end

  def pageviews_and_visitors(site, query) do
    [res] =
      Clickhouse.all(
        from e in base_query(site, query),
          select: {fragment("count(*) as pageviews"), fragment("uniq(user_id) as visitors")}
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

  def top_referrers(site, query, limit \\ 5, include \\ []) do
    referrers =
      Clickhouse.all(
        from e in base_session_query(site, query),
          select:
            {fragment("? as name", e.referrer_source), fragment("any(?) as url", e.referrer),
             fragment("uniq(user_id) as count")},
          group_by: e.referrer_source,
          where: e.referrer_source != "",
          order_by: [desc: fragment("count")],
          limit: ^limit
      )
      |> Enum.map(fn ref ->
        Map.update(ref, "url", nil, fn url -> url && URI.parse("http://" <> url).host end)
      end)

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_referrer_source(site, query)

      Enum.map(referrers, fn referrer ->
        Map.put(referrer, "bounce_rate", bounce_rates[referrer["name"]])
      end)
    else
      referrers
    end
  end

  defp bounce_rates_by_referrer_source(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    Clickhouse.all(
      from s in "sessions",
        select:
          {s.referrer_source, fragment("count(*) as total"),
           fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")},
        where: s.domain == ^site.domain,
        where: s.start >= ^first_datetime and s.start < ^last_datetime,
        where: s.referrer_source != "",
        group_by: s.referrer_source,
        order_by: [desc: fragment("total")],
        limit: 100
    )
    |> Enum.map(fn row -> {row["referrer_source"], row["bounce_rate"]} end)
    |> Enum.into(%{})
  end

  def visitors_from_referrer(site, query, referrer) do
    [res] =
      Clickhouse.all(
        from e in base_query(site, query),
          select: fragment("uniq(user_id) as visitors"),
          where: e.referrer_source == ^referrer
      )

    res["visitors"]
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

  def referrer_drilldown(site, query, referrer, include \\ []) do
    referring_urls =
      Clickhouse.all(
        from e in base_query(site, query),
          select: {fragment("? as name", e.referrer), fragment("uniq(user_id) as count")},
          group_by: e.referrer,
          where: e.referrer_source == ^referrer,
          order_by: [desc: fragment("count")],
          limit: 100
      )

    referring_urls =
      if "bounce_rate" in include do
        bounce_rates = bounce_rates_by_referring_url(site, query)

        Enum.map(referring_urls, fn url ->
          Map.put(url, "bounce_rate", bounce_rates[url["name"]])
        end)
      else
        referring_urls
      end

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

  defp bounce_rates_by_referring_url(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    Clickhouse.all(
      from s in "sessions",
        select:
          {s.referrer, fragment("count(*) as total"),
           fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")},
        where: s.domain == ^site.domain,
        where: s.start >= ^first_datetime and s.start < ^last_datetime,
        where: s.referrer != "",
        group_by: s.referrer,
        order_by: [desc: fragment("total")],
        limit: 100
    )
    |> Enum.map(fn row -> {row["referrer"], row["bounce_rate"]} end)
    |> Enum.into(%{})
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
    pages =
      Clickhouse.all(
        from e in base_query(site, query),
          select: {fragment("? as name", e.pathname), fragment("count(?) as count", e.pathname)},
          group_by: e.pathname,
          order_by: [desc: fragment("count")],
          limit: ^limit
      )

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_page_url(site, query)
      Enum.map(pages, fn url -> Map.put(url, "bounce_rate", bounce_rates[url["name"]]) end)
    else
      pages
    end
  end

  defp bounce_rates_by_page_url(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    Clickhouse.all(
      from s in "sessions",
        select:
          {s.entry_page, fragment("count(*) as total"),
           fragment("round(sum(is_bounce * sign) / sum(sign) * 100) as bounce_rate")},
        where: s.domain == ^site.domain,
        where: s.start >= ^first_datetime and s.start < ^last_datetime,
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

  @available_screen_sizes ["Desktop", "Laptop", "Tablet", "Mobile"]

  def top_screen_sizes(site, query) do
    Clickhouse.all(
      from e in base_query(site, query),
        select: {fragment("? as name", e.screen_size), fragment("uniq(user_id) as count")},
        group_by: e.screen_size,
        where: e.screen_size != ""
    )
    |> Enum.sort(fn %{"name" => screen_size1}, %{"name" => screen_size2} ->
      index1 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size1 end)
      index2 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size2 end)
      index2 > index1
    end)
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

  def current_visitors(site) do
    [res] =
      Clickhouse.all(
        from e in "events",
          select: fragment("uniq(user_id) as visitors"),
          where: e.timestamp >= fragment("now() - INTERVAL 5 MINUTE"),
          where: e.domain == ^site.domain
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

    (fetch_pageview_goals(goals, site, query) ++
       fetch_event_goals(goals, site, query))
    |> sort_conversions()
  end

  defp fetch_event_goals(goals, site, query) do
    events =
      Enum.map(goals, fn goal -> goal.event_name end)
      |> Enum.filter(& &1)

    if Enum.count(events) > 0 do
      Clickhouse.all(
        from e in base_query(site, query, events),
          select: {e.name, fragment("uniq(user_id) as count")},
          group_by: e.name
      )
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query) do
    pages =
      Enum.map(goals, fn goal -> goal.page_path end)
      |> Enum.filter(& &1)

    if Enum.count(pages) > 0 do
      Clickhouse.all(
        from e in base_query(site, query),
          select:
            {fragment("concat('Visit ', ?) as name", e.pathname),
             fragment("uniq(user_id) as count")},
          where: fragment("? IN tuple(?)", e.pathname, ^pages),
          group_by: e.pathname
      )
    else
      []
    end
  end

  defp sort_conversions(conversions) do
    Enum.sort_by(conversions, fn conversion -> -conversion["count"] end)
  end

  defp base_session_query(site, %Query{period: "realtime"}) do
    first_datetime = Timex.now(site.timezone) |> Timex.shift(minutes: -5) |> Timex.Timezone.convert("UTC")

    from(s in "sessions",
      where: s.domain == ^site.domain,
      where: s.timestamp >= ^first_datetime
    )
  end

  defp base_session_query(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    from(s in "sessions",
      where: s.domain == ^site.domain,
      where: s.start >= ^first_datetime and s.start < ^last_datetime
    )
  end

  defp base_query(site, %Query{period: "realtime"}) do
    first_datetime = Timex.now(site.timezone) |> Timex.shift(minutes: -5) |> Timex.Timezone.convert("UTC")

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime
      )
  end

  defp base_query(site, query, events \\ ["pageview"]) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)
    {goal_event, path} = event_name_for_goal(query)

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if path do
        from(e in q, where: e.pathname == ^path)
      else
        q
      end

    if goal_event do
      from(e in q, where: e.name == ^goal_event)
    else
      from(e in q, where: fragment("? IN tuple(?)", e.name, ^events))
    end
  end

  defp date_range_utc_boundaries(date_range, timezone) do
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
