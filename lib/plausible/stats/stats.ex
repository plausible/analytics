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
      from p in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('month', ? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), count(p.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)
    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date |> Timex.beginning_of_month  end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{step_type: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups = Repo.all(
      from p in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('day', ? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), count(p.user_id, :distinct)}
    ) |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.to_date(dt) end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)
    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date  end)

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
      from p in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc('hour', ? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), count(p.user_id, :distinct)}
    )
    |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> NaiveDateTime.to_iso8601(step) end)
    present_index = Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> truncate_to_hour |> NaiveDateTime.truncate(:second) end)
    {plot, labels, present_index}
  end

  def pageviews_and_visitors(site, query) do
    Repo.one(from(
      p in base_query(site, query),
      select: {count(p.id), count(p.user_id, :distinct)}
    ))
  end

  def total_pageviews(site, query) do
    Repo.aggregate(base_query(site, query), :count, :id)
  end

  def unique_visitors(site, query) do
    Repo.one(from(
      p in base_query(site, query),
      select: count(p.user_id, :distinct)
    ))
  end

  def top_referrers(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.referrer_source, count(p.referrer_source)},
      group_by: p.referrer_source,
      where: p.new_visitor == true and not is_nil(p.referrer_source),
      order_by: [desc: 2],
      limit: ^limit
    )
  end

  def visitors_from_referrer(site, query, referrer) do
    Repo.one(from p in base_query(site, query),
      select: count(p),
      where: p.new_visitor == true and p.referrer_source == ^referrer
    )
  end

  def referrer_drilldown(site, query, referrer) do
    Repo.all(from p in base_query(site, query),
      select: {p.referrer, count(p)},
      group_by: p.referrer,
      where: p.new_visitor == true and p.referrer_source == ^referrer,
      order_by: [desc: 2],
      limit: 100
    )
  end

  def top_pages(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.pathname, count(p.pathname)},
      group_by: p.pathname,
      order_by: [desc: count(p.pathname)],
      limit: ^limit
    )
  end

  @available_screen_sizes ["Desktop", "Laptop", "Tablet", "Mobile"]

  def top_screen_sizes(site, query) do
    Repo.all(from p in base_query(site, query),
      select: {p.screen_size, count(p.screen_size)},
      group_by: p.screen_size,
      where: p.new_visitor == true and not is_nil(p.screen_size)
    ) |> Enum.sort(fn {screen_size1, _}, {screen_size2, _} ->
      index1 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size1 end)
      index2 = Enum.find_index(@available_screen_sizes, fn s -> s == screen_size2 end)
      index2 > index1
    end)
  end

  def countries(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.country_code, count(p.country_code)},
      group_by: p.country_code,
      where: p.new_visitor == true and not is_nil(p.country_code),
      order_by: [desc: count(p.country_code)],
      limit: ^limit
    ) |> Enum.map(fn {country_code, count} ->
      {Plausible.Stats.CountryName.from_iso3166(country_code), count}
    end)
  end

  def browsers(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.browser, count(p.browser)},
      group_by: p.browser,
      where: p.new_visitor == true and not is_nil(p.browser),
      order_by: [desc: count(p.browser)],
      limit: ^limit
    )
  end

  def operating_systems(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.operating_system, count(p.operating_system)},
      group_by: p.operating_system,
      where: p.new_visitor == true and not is_nil(p.operating_system),
      order_by: [desc: count(p.operating_system)],
      limit: ^limit
    )
  end

  def current_visitors(site) do
    Repo.one(
      from p in Plausible.Pageview,
      where: p.inserted_at >= fragment("(now() at time zone 'utc') - '5 minutes'::interval"),
      where: p.hostname == ^site.domain,
      select: count(p.user_id, :distinct)
    )
  end

  defp base_query(site, query) do
    {:ok, first} = NaiveDateTime.new(query.date_range.first, ~T[00:00:00])
    first_datetime = Timex.to_datetime(first, site.timezone)

    {:ok, last} = NaiveDateTime.new(query.date_range.last |> Timex.shift(days: 1), ~T[00:00:00])
    last_datetime = Timex.to_datetime(last, site.timezone)

    from(p in Plausible.Pageview,
      where: p.hostname == ^site.domain,
      where: p.inserted_at >= ^first_datetime and p.inserted_at < ^last_datetime
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
