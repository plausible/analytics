defmodule Plausible.Stats do
  use Plausible.Repo
  alias Plausible.Stats.Query

  def calculate_plot(site, query) do
    groups = pageview_groups(site, query)

    steps = case query.step_type do
      "hour" ->
        Enum.map(24..0, fn shift ->
          Timex.now(site.timezone)
          |> Timex.shift(hours: -shift)
          |> DateTime.to_naive
          |> truncate_to_hour
          |> NaiveDateTime.truncate(:second)
        end)
      "date" ->
        query.date_range
    end

    Enum.map(steps, fn step -> groups[step] || 0 end)
  end

  def labels(_site, %Query{step_type: "date"} = query) do
    Enum.map(query.date_range, fn date ->
      Timex.format!(date, "{D} {Mshort}")
    end)
  end

  def labels(site, %Query{step_type: "hour"}) do
    Enum.map(24..0, fn shift ->
      Timex.now(site.timezone)
      |> Timex.shift(hours: -shift)
      |> DateTime.to_naive
      |> truncate_to_hour
      |> Timex.format!("{h12}{am}")
    end)
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

  def top_pages(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.pathname, count(p.pathname)},
      group_by: p.pathname,
      order_by: [desc: count(p.pathname)],
      limit: ^limit
    )
  end

  def top_screen_sizes(site, query, limit \\ 5) do
    mobile_q = from(
      p in base_query(site, query),
      where: p.screen_width < 600,
      select: count(p.session_id, :distinct)
    )
    mobile = Repo.one(mobile_q)

    tablet_q = from(
      p in base_query(site, query),
      where: p.screen_width >= 600 and p.screen_width < 992,
      select: count(p.session_id, :distinct)
    )
    tablet = Repo.one(tablet_q)

    desktop_q = from(
      p in base_query(site, query),
      where: p.screen_width >= 992,
      select: count(p.session_id, :distinct)
    )
    desktop = Repo.one(desktop_q)

    [
      {"Mobile", mobile},
      {"Tablet", tablet},
      {"Desktop", desktop}
    ]
    |> Enum.filter(fn {_, n} -> n > 0 end)
    |> Enum.sort(fn {_, n}, {_, n1} -> n >= n1 end)
  end

  def device_types(site, query) do
    Repo.all(from p in base_query(site, query),
      select: {p.device_type, count(p.device_type)},
      group_by: p.device_type,
      where: p.new_visitor == true,
      order_by: [desc: count(p.device_type)],
      limit: 5
    )
  end

  def browsers(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.browser, count(p.browser)},
      group_by: p.browser,
      where: p.new_visitor == true,
      order_by: [desc: count(p.browser)],
      limit: ^limit
    )
  end

  def operating_systems(site, query, limit \\ 5) do
    Repo.all(from p in base_query(site, query),
      select: {p.operating_system, count(p.operating_system)},
      group_by: p.operating_system,
      where: p.new_visitor == true,
      order_by: [desc: count(p.operating_system)],
      limit: ^limit
    )
  end

  defp base_query(site, %Query{step_type: "hour"}) do
    from(p in Plausible.Pageview,
      where: p.hostname == ^site.domain,
      where: p.inserted_at >= fragment("date_trunc('hour', (now() at time zone 'utc') - '24 hours'::interval)")
    )
  end

  defp base_query(site, query) do
    from(p in Plausible.Pageview,
      where: p.hostname == ^site.domain,
      where: type(fragment("(? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), :date) >= ^query.date_range.first and type(fragment("(? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), :date) <= ^query.date_range.last
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

  defp pageview_groups(site, %Query{step_type: "date"} = query) do
    Repo.all(
      from p in base_query(site, query),
      select: {fragment("(? at time zone 'utc' at time zone ?)::date", p.inserted_at, ^site.timezone), count(p.id)},
      group_by: 1,
      order_by: 1
    ) |> Enum.into(%{})
  end

  defp pageview_groups(site, %Query{step_type: "hour"} = query) do
    Repo.all(
      from p in base_query(site, query),
      group_by: 1,
      order_by: 1,
      select: {fragment("date_trunc(?, ? at time zone 'utc' at time zone ?)", "hour", p.inserted_at, ^site.timezone), count(p.id)}
    )
    |> Enum.into(%{})
    |> transform_keys(fn dt -> NaiveDateTime.truncate(dt, :second) end)
  end
end
