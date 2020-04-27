defmodule Plausible.Stats do
  use Plausible.Repo
  alias Plausible.Stats.Query

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
            round((visitors - old_visitors) / old_visitors * 100),
        }

    end
  end

  def calculate_plot(site, %Query{step_type: "month"} = query) do
    q = """
    SELECT toStartOfMonth(timestamp) as month, uniq(user_id) as visitors
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    GROUP BY month
    ORDER BY month
    """
    res = query!(q, [site.domain] ++ date_range(site, query))
          |> Enum.map(fn row -> {row["month"], row["visitors"]} end)
          |> Enum.into(%{})

    steps = Enum.map((query.steps - 1)..0, fn shift ->
      Timex.now(site.timezone)
      |> Timex.beginning_of_month
      |> Timex.shift(months: -shift)
      |> DateTime.to_date
    end)

    compare_groups = if query.filters["goal"] do
      {goal_event, path} = event_name_for_goal(query)

      q = """
      SELECT toStartOfMonth(timestamp) as month, uniq(user_id) as visitors
      FROM events
      WHERE name=?
      AND domain=?
      AND timestamp BETWEEN ? and ?
      #{ if path, do: "AND pathname=?", else: "" }
      GROUP BY month
      ORDER BY month
      """
      params = Enum.filter([goal_event, site.domain] ++ date_range(site, query) ++ [path], &(!is_nil(&1)))
      query!(q, params)
          |> Enum.map(fn row -> {row["month"], row["visitors"]} end)
          |> Enum.into(%{})
    end

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date |> Timex.beginning_of_month end)
    plot = Enum.map(steps, fn step -> res[step] || 0 end)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, compare_plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    q = """
    SELECT toDate(timestamp) as day, uniq(user_id) as visitors
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    GROUP BY day
    ORDER BY day
    """
    res = query!(q, [site.domain] ++ date_range(site, query))
          |> Enum.map(fn row -> {row["day"], row["visitors"]} end)
          |> Enum.into(%{})

    compare_groups = if query.filters["goal"] do
      Repo.all(
        from e in base_query(site, query),
        group_by: 1,
        order_by: 1,
        select: {fragment("date_trunc('day', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.fingerprint, :distinct)}
      ) |> Enum.into(%{})
      |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)
    end

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date  end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> res[step] || 0 end)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, compare_plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "hour"} = query) do
    {:ok, beginning_of_day} = NaiveDateTime.new(query.date_range.first, ~T[00:00:00])

    steps = Enum.map(0..23, fn shift ->
      beginning_of_day
      |> Timex.shift(hours: shift)
      |> truncate_to_hour
      |> NaiveDateTime.truncate(:second)
    end)

    groups = Repo.all(
      from e in base_query(site, %{query | filters: %{}}),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.fingerprint, :distinct)}
    )
    |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)

    compare_groups = if query.filters["goal"] do
      Repo.all(
        from e in base_query(site, query),
        group_by: 1,
        order_by: 1,
        select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.fingerprint, :distinct)}
      )
      |> Enum.into(%{})
      |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)
    end

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> truncate_to_hour |> NaiveDateTime.truncate(:second) end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> NaiveDateTime.to_iso8601(step) end)
    {plot, compare_plot, labels, present_index}
  end

  def bounce_rate(site, query) do
    q = """
    SELECT round(countIf(is_bounce = 1) / count(*) * 100) as bounce_rate
    FROM sessions
    WHERE domain=?
    AND start BETWEEN ? and ?
    """

    [res] = query!(q, [site.domain] ++ date_range(site, query))
    res["bounce_rate"] || 0
  end

  defp date_range(site, query) do
    {:ok, first} = NaiveDateTime.new(query.date_range.first, ~T[00:00:00])
    first_datetime = Timex.to_datetime(first, site.timezone)
    |> Timex.Timezone.convert("UTC")

    {:ok, last} = NaiveDateTime.new(query.date_range.last |> Timex.shift(days: 1), ~T[00:00:00])
    last_datetime = Timex.to_datetime(last, site.timezone)
    |> Timex.Timezone.convert("UTC")

    [first_datetime, last_datetime]
  end

  def pageviews_and_visitors(site, query) do
    q = """
    SELECT count(*) as pageviews, uniq(user_id) as visitors
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    """

    [res] = query!(q, [site.domain] ++ date_range(site, query))
    {res["pageviews"], res["visitors"]}
  end

  defp query!(q, args) do
    res = Clickhousex.query!(:clickhouse, q, args, log: {Plausible.Stats, :log, []})
    Enum.map(res.rows, fn row ->
      Enum.zip(res.columns, row)
      |> Enum.into(%{})
    end)
  end

  def log(query) do
    require Logger
    timing = System.convert_time_unit(query.connection_time, :native, :millisecond)
    statement = String.replace(query.query.statement, "\n", " ")
    Logger.debug("Clickhouse query OK db=#{timing}ms\n#{statement} #{inspect query.params}")
  end

  def unique_visitors(site, query) do
    {goal_event, path} = event_name_for_goal(query)
    event = goal_event || "pageview"

    q = """
    SELECT uniq(user_id) as visitors
    FROM events
    WHERE name=?
    AND domain=?
    AND timestamp BETWEEN ? and ?
    #{ if path, do: "AND pathname=?", else: "" }
    """
    params = Enum.filter([event, site.domain] ++ date_range(site, query) ++ [path], &(!is_nil(&1)))
    [res] = query!(q, params)
    res["visitors"]
  end

  def top_referrers_for_goal(site, query, limit \\ 5) do
    q = from(e in base_query(site, query),
      select: %{name: e.initial_referrer_source, url: min(e.initial_referrer), count: count(e.fingerprint, :distinct)},
      group_by: e.initial_referrer_source,
      where: not is_nil(e.initial_referrer_source),
      order_by: [desc: 3],
      limit: ^limit
    )
    IO.inspect(Ecto.Adapters.SQL.to_sql(:all, Repo, q))
    Repo.all(q) |> Enum.map(fn ref ->
      Map.update(ref, :url, nil, fn url -> url && URI.parse("http://" <> url).host end)
    end)
  end

  def top_referrers(site, query, limit \\ 5, include \\ []) do
    q = """
    SELECT referrer_source, any(referrer) as url, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND isNotNull(referrer_source)
    GROUP BY referrer_source
    ORDER BY count DESC
    LIMIT ?
    """

    referrers = query!(q, [site.domain] ++ date_range(site, query) ++ [limit])
          |> Enum.map(fn ref ->
            Map.update(ref, "url", nil, fn url -> url && URI.parse("http://" <> url).host end)
            |> Map.put("name", ref["referrer_source"])
            |> Map.delete("referrer_source")
          end)

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_referrer_source(site, query, Enum.map(referrers, fn ref -> ref["name"] end))

      Enum.map(referrers, fn referrer ->
        Map.put(referrer, "bounce_rate", bounce_rates[referrer["name"]])
      end)
    else
      referrers
    end
  end

  defp bounce_rates_by_referrer_source(site, query, referrers) do
    q = """
    SELECT referrer_source, count(*) as total, round(countIf(is_bounce = 1) / total * 100) as bounce_rate
    FROM sessions
    WHERE domain=?
    AND start BETWEEN ? and ?
    AND isNotNull(referrer_source)
    GROUP BY referrer_source
    ORDER BY total DESC
    LIMIT 100
    """

    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn row -> {row["referrer_source"], row["bounce_rate"]} end)
    |> Enum.into(%{})
  end

  def visitors_from_referrer(site, query, referrer) do
    q = """
    SELECT uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND referrer_source=?
    """
    [res] = query!(q, [site.domain] ++ date_range(site, query) ++ [referrer])
    res["count"]
  end

  def conversions_from_referrer(site, query, referrer) do
    Repo.one(
      from e in base_query(site, query),
      select: count(e.fingerprint, :distinct),
      where: e.initial_referrer_source == ^referrer
    )
  end

  def referrer_drilldown(site, query, referrer, include \\ []) do
    q = """
    SELECT referrer, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND referrer_source=?
    GROUP BY referrer
    ORDER BY count DESC
    LIMIT 100
    """

    referring_urls = query!(q, [site.domain] ++ date_range(site, query) ++ [referrer])
          |> Enum.map(fn ref ->
            Map.put(ref, "name", ref["referrer"])
            |> Map.delete("referrer")
          end)

    referring_urls = if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_referring_url(site, query)
      Enum.map(referring_urls, fn url -> Map.put(url, "bounce_rate", bounce_rates[url["name"]]) end)
    else
      referring_urls
    end

    if referrer == "Twitter" do
      urls = Enum.map(referring_urls, &(&1[:name]))

      tweets = Repo.all(
        from t in Plausible.Twitter.Tweet,
        where: t.link in ^urls
      ) |> Enum.group_by(&(&1.link))

      Enum.map(referring_urls, fn url ->
        Map.put(url, :tweets, tweets[url[:name]])
      end)
    else
      referring_urls
    end
  end

  def referrer_drilldown_for_goal(site, query, referrer) do
    Repo.all(
      from e in base_query(site, query),
      select: %{name: e.initial_referrer, count: count(e.fingerprint, :distinct)},
      group_by: e.initial_referrer,
      where: e.initial_referrer_source == ^referrer,
      order_by: [desc: 2],
      limit: 100
    )
  end

  defp bounce_rates_by_referring_url(site, query) do
    q = """
    SELECT referrer, count(*) as total, round(countIf(is_bounce = 1) / total * 100) as bounce_rate
    FROM sessions
    WHERE domain=?
    AND start BETWEEN ? and ?
    AND isNotNull(referrer)
    GROUP BY referrer
    ORDER BY total DESC
    LIMIT 100
    """

    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn row -> {row["referrer"], row["bounce_rate"]} end)
    |> Enum.into(%{})
  end

  def top_pages(site, query, limit \\ 5, include \\ []) do
    q = """
    SELECT pathname, count(*) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    GROUP BY pathname
    ORDER BY count DESC
    LIMIT ?
    """

    pages = query!(q, [site.domain] ++ date_range(site, query) ++ [limit])
          |> Enum.map(fn page ->
            Map.put(page, "name", page["pathname"])
            |> Map.delete("pathname")
          end)

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_page_url(site, query)
      Enum.map(pages, fn url -> Map.put(url, "bounce_rate", bounce_rates[url["name"]]) end)
    else
      pages
    end
  end

  defp bounce_rates_by_page_url(site, query) do
    q = """
    SELECT entry_page, count(*) as total, round(countIf(is_bounce = 1) / total * 100) as bounce_rate
    FROM sessions
    WHERE domain=?
    AND start BETWEEN ? and ?
    GROUP BY entry_page
    ORDER BY total DESC
    LIMIT 100
    """

    query!(q, [site.domain] ++ date_range(site, query))
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
    q = """
    SELECT screen_size, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND isNotNull(screen_size)
    GROUP BY screen_size
    ORDER BY count DESC
    """

    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn stat ->
      Map.put(stat, "name", stat["screen_size"])
      |> Map.delete("screen_size")
    end) |> Enum.sort(fn %{"name" => screen_size1}, %{"name" => screen_size2} ->
      index1 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size1 end)
      index2 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size2 end)
      index2 > index1
    end)
    |> add_percentages
  end

  def countries(site, query) do
    q = """
    SELECT country_code, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    GROUP BY country_code
    ORDER BY count DESC
    """

    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn country ->
      Map.put(country, "name", country["country_code"])
      |> Map.delete("country_code")
    end)
    |> Enum.map(fn stat ->
      two_letter_code = stat["name"]
      stat
      |> Map.put("name", Plausible.Stats.CountryName.to_alpha3(two_letter_code))
      |> Map.put("full_country_name", Plausible.Stats.CountryName.from_iso3166(two_letter_code))
    end)
    |> add_percentages
  end

  def browsers(site, query, limit \\ 5) do
    q = """
    SELECT browser, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND isNotNull(browser)
    GROUP BY browser
    ORDER BY count DESC
    """
    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn country ->
      Map.put(country, "name", country["browser"])
      |> Map.delete("browser")
    end)
    |> add_percentages
    |> Enum.take(limit)
  end

  def operating_systems(site, query, limit \\ 5) do
    q = """
    SELECT operating_system, uniq(user_id) as count
    FROM events
    WHERE name='pageview'
    AND domain=?
    AND timestamp BETWEEN ? and ?
    AND isNotNull(operating_system)
    GROUP BY operating_system
    ORDER BY count DESC
    """
    query!(q, [site.domain] ++ date_range(site, query))
    |> Enum.map(fn country ->
      Map.put(country, "name", country["operating_system"])
      |> Map.delete("operating_system")
    end)
    |> add_percentages
    |> Enum.take(limit)
  end

  def current_visitors(site) do
    Repo.one(
      from e in Plausible.Event,
      where: e.timestamp >= fragment("(now() at time zone 'utc') - '5 minutes'::interval"),
      where: e.domain == ^site.domain,
      select: count(e.fingerprint, :distinct)
    )
  end

  def goal_conversions(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    [%{name: goal, count: unique_visitors(site, query)}]
  end

  def goal_conversions(site, query) do
    goals = Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    fetch_pageview_goals(goals, site, query)
    ++ fetch_event_goals(goals, site, query)
    |> sort_conversions()
  end

  defp fetch_event_goals(goals, site, query) do
    events = Enum.map(goals, fn goal -> goal.event_name end)
             |> Enum.filter(&(&1))

    if Enum.count(events) > 0 do
      q = """
      SELECT name, uniq(user_id) as count
      FROM events
      WHERE domain=?
      AND name IN ?
      AND timestamp BETWEEN ? and ?
      GROUP BY name
      """
      query!(q, [site.domain, events] ++ date_range(site, query))
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query) do
    pages = Enum.map(goals, fn goal -> goal.page_path end)
             |> Enum.filter(&(&1))

    if Enum.count(pages) > 0 do
      q = """
      SELECT pathname, uniq(user_id) as count
      FROM events
      WHERE name='pageview'
      AND domain=?
      AND pathname IN ?
      AND timestamp BETWEEN ? and ?
      GROUP BY pathname
      """
      query!(q, [site.domain, pages] ++ date_range(site, query))
          |> Enum.map(fn c ->
            Map.put(c, "name", "Visit " <> c["pathname"])
            |> Map.delete("pathname")
          end)
    else
      []
    end
  end

  defp sort_conversions(conversions) do
    Enum.sort_by(conversions, fn conversion -> -conversion["count"] end)
  end

  defp base_query(site, query, events \\ ["pageview"]) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)
    {goal_event, path} = event_name_for_goal(query)

    q = from(e in Plausible.Event,
      where: e.domain == ^site.domain,
      where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
    )

    q = if path do
      from(e in q, where: e.pathname == ^path)
    else
      q
    end

    if goal_event do
      from(e in q, where: e.name == ^goal_event)
    else
      from(e in q, where: e.name in ^events)
    end
  end

  defp date_range_utc_boundaries(date_range, timezone) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])
    first_datetime = Timex.to_datetime(first, timezone)
    |> Timex.Timezone.convert("UTC")

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])
    last_datetime = Timex.to_datetime(last, timezone)
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

  defp transform_keys(map, fun) do
    for {key, val} <- map, into: %{} do
      {fun.(key), val}
    end
  end

  defp truncate_to_hour(datetime) do
    {:ok, datetime} = NaiveDateTime.new(datetime.year, datetime.month, datetime.day, datetime.hour, 0, 0, 0)
    datetime
  end
end
