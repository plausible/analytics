defmodule Plausible.Stats do
  use Plausible.Repo
  alias Plausible.Stats.Query

  def compare_pageviews_and_visitors(site, query, {pageviews, visitors}) do
    query = Query.shift_back(query)
    {old_pageviews, old_visitors} = pageviews_and_visitors(site, query)
    if old_visitors > 0 do
      {
        round((pageviews - old_pageviews) / old_pageviews * 100),
        round((visitors - old_visitors) / old_visitors * 100),
      }
    else
      {nil, nil}
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
      from e in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('month', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date |> Timex.beginning_of_month end)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups = Repo.all(
      from e in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('day', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date  end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
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
      from e in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", e.timestamp, ^site.timezone), count(e.user_id, :distinct)}
    )
    |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)

    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> truncate_to_hour |> NaiveDateTime.truncate(:second) end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    labels = Enum.map(steps, fn step -> NaiveDateTime.to_iso8601(step) end)
    {plot, labels, present_index}
  end

  def pageviews_and_visitors(site, query) do
    Repo.one(from(
      e in base_query(site, query),
      select: {count(e.id), count(e.user_id, :distinct)}
    ))
  end

  def top_referrers(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.referrer_source, count(e.referrer_source)},
      group_by: e.referrer_source,
      where: e.new_visitor == true and not is_nil(e.referrer_source),
      order_by: [desc: 2],
      limit: ^limit
    )
  end

  def visitors_from_referrer(site, query, referrer) do
    Repo.one(from e in base_query(site, query),
      select: count(e),
      where: e.new_visitor == true and e.referrer_source == ^referrer
    )
  end

  def referrer_drilldown(site, query, referrer) do
    Repo.all(from e in base_query(site, query),
      select: {e.referrer, count(e)},
      group_by: e.referrer,
      where: e.new_visitor == true and e.referrer_source == ^referrer,
      order_by: [desc: 2],
      limit: 100
    )
  end

  def top_pages(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.pathname, count(e.pathname)},
      group_by: e.pathname,
      order_by: [desc: count(e.pathname)],
      limit: ^limit
    )
  end

  @available_screen_sizes ["Desktop", "Laptop", "Tablet", "Mobile"]

  def top_screen_sizes(site, query) do
    Repo.all(from e in base_query(site, query),
      select: {e.screen_size, count(e.screen_size)},
      group_by: e.screen_size,
      where: e.new_visitor == true and not is_nil(e.screen_size)
    ) |> Enum.sort(fn {screen_size1, _}, {screen_size2, _} ->
      index1 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size1 end)
      index2 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size2 end)
      index2 > index1
    end)
  end

  def countries(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.country_code, count(e.country_code)},
      group_by: e.country_code,
      where: e.new_visitor == true and not is_nil(e.country_code),
      order_by: [desc: count(e.country_code)],
      limit: ^limit
    ) |> Enum.map(fn {country_code, count} ->
      {Plausible.Stats.CountryName.from_iso3166(country_code), count}
    end)
  end

  def browsers(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.browser, count(e.browser)},
      group_by: e.browser,
      where: e.new_visitor == true and not is_nil(e.browser),
      order_by: [desc: count(e.browser)],
      limit: ^limit
    )
  end

  def operating_systems(site, query, limit \\ 5) do
    Repo.all(from e in base_query(site, query),
      select: {e.operating_system, count(e.operating_system)},
      group_by: e.operating_system,
      where: e.new_visitor == true and not is_nil(e.operating_system),
      order_by: [desc: count(e.operating_system)],
      limit: ^limit
    )
  end

  def current_visitors(site) do
    Repo.one(
      from e in Plausible.Event,
      where: e.timestamp >= fragment("(now() at time zone 'utc') - '5 minutes'::interval"),
      where: e.hostname == ^site.domain,
      select: count(e.user_id, :distinct)
    )
  end

  def goal_conversions(site, query, limit \\ 5) do
    goals = Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    conversions = fetch_pageview_goals(goals, site, query)
                  ++ fetch_event_goals(goals, site, query)
                  |> sort_conversions
  end

  defp fetch_event_goals(goals, site, query) do
    {:ok, first} = NaiveDateTime.new(query.date_range.first, ~T[00:00:00])
    first_datetime = Timex.to_datetime(first, site.timezone)

    {:ok, last} = NaiveDateTime.new(query.date_range.last |> Timex.shift(days: 1), ~T[00:00:00])
    last_datetime = Timex.to_datetime(last, site.timezone)

    events = Enum.map(goals, fn goal -> goal.name end)
             |> Enum.filter(&(&1))

    if Enum.count(events) > 0 do
      Repo.all(
        from e in Plausible.Event,
        where: e.hostname == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime,
        where: e.name in ^events,
        group_by: e.name,
        select: {e.name, count(e.user_id, :distinct)}
      )
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query), do: []

  defp sort_conversions(conversions), do: conversions

  defp base_query(site, query) do
    {:ok, first} = NaiveDateTime.new(query.date_range.first, ~T[00:00:00])
    first_datetime = Timex.to_datetime(first, site.timezone)

    {:ok, last} = NaiveDateTime.new(query.date_range.last |> Timex.shift(days: 1), ~T[00:00:00])
    last_datetime = Timex.to_datetime(last, site.timezone)

    from(e in Plausible.Event,
      where: e.name == "pageview",
      where: e.hostname == ^site.domain,
      where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
    )
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
