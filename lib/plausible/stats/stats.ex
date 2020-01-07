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
    steps = Enum.map((query.steps - 1)..0, fn shift ->
      Timex.now(site.timezone)
      |> Timex.beginning_of_month
      |> Timex.shift(months: -shift)
      |> DateTime.to_date
    end)

    groups = Repo.all(
      from e in base_query(site, %{query | filters: %{}}),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('month', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    compare_groups = if query.filters["goal"] do
      Repo.all(
        from e in base_query(site, query),
        group_by: 1,
        order_by: 1,
        select: {fragment("date_trunc('month', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
      ) |> Enum.into(%{})
      |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)
    end

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date |> Timex.beginning_of_month end)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    compare_plot = compare_groups && Enum.map(steps, fn step -> compare_groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, compare_plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups = Repo.all(
      from e in base_query(site, %{ query | filters: %{} }),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('day', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    compare_groups = if query.filters["goal"] do
      Repo.all(
        from e in base_query(site, query),
        group_by: 1,
        order_by: 1,
        select: {fragment("date_trunc('day', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
      ) |> Enum.into(%{})
      |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)
    end

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date  end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
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
      select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    )
    |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)

    compare_groups = if query.filters["goal"] do
      Repo.all(
        from e in base_query(site, query),
        group_by: 1,
        order_by: 1,
        select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
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
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    sessions_query = from(s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime
    )
    total_sessions = Repo.one( from s in sessions_query, select: count(s))
    bounced_sessions = Repo.one(from s in sessions_query, where: s.is_bounce, select: count(s))

    case total_sessions do
      0 -> 0
      total -> round(bounced_sessions / total * 100)
    end
  end

  def session_length(site, query) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    Repo.one(from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      select: coalesce(avg(s.length), 0)
    ) |> Decimal.round |> Decimal.to_integer
  end

  def pageviews_and_visitors(site, query) do
    Repo.one(from(
      e in base_query(site, query),
      select: {count(e.id), count(e.user_id, :distinct)}
    ))
  end

  def unique_visitors(site, query) do
    Repo.one(from(
      e in base_query(site, query),
      select: count(e.user_id, :distinct)
    ))
  end

  def top_referrers(site, query, limit \\ 5, include \\ []) do
    referrers = Repo.all(from e in base_query(site, query),
      select: %{name: e.referrer_source, count: count(e.user_id, :distinct)},
      group_by: e.referrer_source,
      where: not is_nil(e.referrer_source),
      order_by: [desc: 2],
      limit: ^limit
    )

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_referrer_source(site, query, Enum.map(referrers, fn ref -> ref[:name] end))

      Enum.map(referrers, fn referrer ->
        Map.put(referrer, :bounce_rate, bounce_rates[referrer[:name]])
      end)
    else
      referrers
    end
  end

  defp bounce_rates_by_referrer_source(site, query, referrers) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    total_sessions_by_referrer = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.referrer_source in ^referrers,
      group_by: s.referrer_source,
      select: {s.referrer_source, count(s.id)}
    ) |> Enum.into(%{})

    bounced_sessions_by_referrer = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.is_bounce,
      where: s.referrer_source in ^referrers,
      group_by: s.referrer_source,
      select: {s.referrer_source, count(s.id)}
    ) |> Enum.into(%{})

    Enum.reduce(referrers, %{}, fn referrer, acc ->
      total_sessions = Map.get(total_sessions_by_referrer, referrer, 0)
      bounced_sessions = Map.get(bounced_sessions_by_referrer, referrer, 0)

      bounce_rate = if total_sessions > 0 do
        round(bounced_sessions / total_sessions * 100)
      end

      Map.put(acc, referrer, bounce_rate)
    end)
  end

  def visitors_from_referrer(site, query, referrer) do
    Repo.one(
      from e in base_query(site, query),
      select: count(e.user_id, :distinct),
      where: e.referrer_source == ^referrer
    )
  end

  def referrer_drilldown(site, query, referrer, include \\ []) do
    referring_urls = Repo.all(from e in base_query(site, query),
      select: %{name: e.referrer, count: count(e.user_id, :distinct)},
      group_by: e.referrer,
      where: e.referrer_source == ^referrer,
      order_by: [desc: 2],
      limit: 100
    )

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_referring_url(site, query, Enum.map(referring_urls, fn ref -> ref[:name] end))

      Enum.map(referring_urls, fn url ->
        Map.put(url, :bounce_rate, bounce_rates[url[:name]])
      end)
    else
      referring_urls
    end
  end

  defp bounce_rates_by_referring_url(site, query, referring_urls) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    total_sessions_by_url = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.referrer in ^referring_urls,
      group_by: s.referrer,
      select: {s.referrer, count(s.id)}
    ) |> Enum.into(%{})

    bounced_sessions_by_url = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.is_bounce,
      where: s.referrer in ^referring_urls,
      group_by: s.referrer,
      select: {s.referrer, count(s.id)}
    ) |> Enum.into(%{})

    Enum.reduce(referring_urls, %{}, fn url, acc ->
      total_sessions = Map.get(total_sessions_by_url, url, 0)
      bounced_sessions = Map.get(bounced_sessions_by_url, url, 0)

      bounce_rate = if total_sessions > 0 do
        round(bounced_sessions / total_sessions * 100)
      end

      Map.put(acc, url, bounce_rate)
    end)
  end

  def top_pages(site, query, limit \\ 5, include \\ []) do
    pages = Repo.all(from e in base_query(site, query),
      select: %{name: e.pathname, count: count(e.pathname)},
      group_by: e.pathname,
      order_by: [desc: count(e.pathname)],
      limit: ^limit
    )

    if "bounce_rate" in include do
      bounce_rates = bounce_rates_by_page_url(site, query, Enum.map(pages, fn page -> page[:name] end))

      Enum.map(pages, fn url ->
        Map.put(url, :bounce_rate, bounce_rates[url[:name]])
      end)
    else
      pages
    end
  end

  defp bounce_rates_by_page_url(site, query, page_urls) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)

    total_sessions_by_url = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.entry_page in ^page_urls,
      group_by: s.entry_page,
      select: {s.entry_page, count(s.id)}
    ) |> Enum.into(%{})

    bounced_sessions_by_url = Repo.all(
      from s in Plausible.Session,
      where: s.hostname == ^site.domain,
      where: s.new_visitor,
      where: s.start >= ^first_datetime and s.start < ^last_datetime,
      where: s.is_bounce,
      where: s.entry_page in ^page_urls,
      group_by: s.entry_page,
      select: {s.entry_page, count(s.id)}
    ) |> Enum.into(%{})

    Enum.reduce(page_urls, %{}, fn url, acc ->
      total_sessions = Map.get(total_sessions_by_url, url, 0)
      bounced_sessions = Map.get(bounced_sessions_by_url, url, 0)

      bounce_rate = if total_sessions > 0 do
        round(bounced_sessions / total_sessions * 100)
      end

      Map.put(acc, url, bounce_rate)
    end)
  end

  @available_screen_sizes ["Desktop", "Laptop", "Tablet", "Mobile"]

  def top_screen_sizes(site, query) do
    Repo.all(from e in base_query(site, query),
      select: {e.screen_size, count(e.user_id, :distinct)},
      group_by: e.screen_size,
      where: not is_nil(e.screen_size)
    )
    |> Enum.sort(fn {screen_size1, _}, {screen_size2, _} ->
      index1 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size1 end)
      index2 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size2 end)
      index2 > index1
    end)
    |> add_percentages
  end

  defp add_percentages(stat_list) do
    total = Enum.reduce(stat_list, 0, fn {_, count}, total -> total + count end)
    Enum.map(stat_list, fn {stat, count} ->
      %{
        name: stat,
        count: count,
        percentage: round(count / total * 100)
      }
    end)
  end

  def countries(site, query, limit \\ 5) do
     Repo.all(from e in base_query(site, query),
      select: {e.country_code, count(e.user_id, :distinct)},
      group_by: e.country_code,
      where: not is_nil(e.country_code),
      order_by: [desc: 2]
    )
    |> Enum.map(fn {country_code, count} ->
      {Plausible.Stats.CountryName.from_iso3166(country_code), count}
    end)
    |> add_percentages
    |> Enum.take(limit)
  end

  def browsers(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.browser, count(e.user_id, :distinct)},
      group_by: e.browser,
      where: not is_nil(e.browser),
      order_by: [desc: 2]
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def operating_systems(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.operating_system, count(e.user_id, :distinct)},
      group_by: e.operating_system,
      where: not is_nil(e.operating_system),
      order_by: [desc: 2]
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def current_visitors(site) do
    Repo.one(
      from e in Plausible.Event,
      where: e.timestamp >= fragment("(now() at time zone 'utc') - '5 minutes'::interval"),
      where: e.hostname == ^site.domain,
      select: count(e.user_id, :distinct)
    )
  end

  def goal_conversions(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    Repo.all(from e in base_query(site, query),
      select: count(e.user_id, :distinct),
      group_by: e.name,
      order_by: [desc: 1]
    ) |> Enum.map(fn count -> %{name: goal, count: count} end)
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
      Repo.all(
        from e in base_query(site, query, events),
        group_by: e.name,
        select: %{name: e.name, count: count(e.user_id, :distinct)}
      )
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query) do
    pages = Enum.map(goals, fn goal -> goal.page_path end)
             |> Enum.filter(&(&1))

    if Enum.count(pages) > 0 do
      Repo.all(
        from e in base_query(site, query),
        where: e.pathname in ^pages,
        group_by: e.pathname,
        select: %{name: fragment("concat('Visit ', ?)", e.pathname), count: count(e.user_id, :distinct)}
      )
    else
      []
    end
  end

  defp sort_conversions(conversions) do
    Enum.sort_by(conversions, fn conversion -> -conversion[:count] end)
  end

  defp base_query(site, query, events \\ ["pageview"]) do
    {first_datetime, last_datetime} = date_range_utc_boundaries(query.date_range, site.timezone)
    {goal_event, path} = event_name_for_goal(query)

    q = from(e in Plausible.Event,
      where: e.hostname == ^site.domain,
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
