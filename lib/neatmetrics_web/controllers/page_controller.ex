defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller
  use Neatmetrics.Repo

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def analytics(conn, %{"website" => website} = params) do
    {period, date_range} = get_date_range(params)

    pageviews = Repo.all(
      from p in Neatmetrics.Pageview,
      where: p.hostname == ^website,
      where: type(p.inserted_at, :date) >= ^date_range.first and type(p.inserted_at, :date) <= ^date_range.last
    )

    pageview_groups = Enum.group_by(pageviews, fn pageview -> NaiveDateTime.to_date(pageview.inserted_at) end)

    plot = Enum.map(date_range, fn day ->
      Enum.count(pageview_groups[day] || [])
    end)

    labels = Enum.map(date_range, fn date ->
      Timex.format!(date, "{WDshort} {D} {Mshort}")
    end)

    user_agents = pageviews
      |> Enum.filter(fn pv -> pv.user_agent && pv.new_visitor end)
      |> Enum.map(fn pv -> UAInspector.parse_client(pv.user_agent) end)

    device_types = user_agents
      |> Enum.group_by(&device_type/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    browsers = user_agents
      |> Enum.group_by(&browser_name/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    operating_systems = user_agents
      |> Enum.group_by(&operating_system/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    top_referrers = pageviews
      |> Enum.filter(fn pv -> pv.referrer && pv.new_visitor && !String.contains?(pv.referrer, pv.hostname) end)
      |> Enum.map(&(RefInspector.parse(&1.referrer)))
      |> Enum.group_by(&(&1.source))
      |> Enum.map(fn {ref, views} -> {ref, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    top_pages = Enum.group_by(pageviews, &(&1.pathname))
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    top_screen_sizes = Enum.group_by(pageviews, &Neatmetrics.Pageview.screen_string/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(10)

    render(conn, "analytics.html",
      plot: plot,
      labels: labels,
      pageviews: Enum.count(pageviews),
      unique_visitors: Enum.filter(pageviews, fn pv -> pv.new_visitor end) |> Enum.count,
      bounce_rate: calculate_bounce_rate(pageviews),
      average_session: "1:31",
      top_referrers: top_referrers,
      top_pages: top_pages,
      top_screen_sizes: top_screen_sizes,
      device_types: device_types,
      browsers: browsers,
      operating_systems: operating_systems,
      hostname: website,
      title: "Neatmetrics · " <> website,
      selected_period: period
    )
  end

  defp get_date_range(%{"period" => "today"}) do
    date_range = Date.range(Timex.today(), Timex.today())
    {"today", date_range}
  end

  defp get_date_range(%{"period" => "7days"}) do
    start_date = Timex.shift(Timex.today(), days: -7)
    date_range = Date.range(start_date, Timex.today())
    {"7days", date_range}
  end

  defp get_date_range(%{"period" => "30days"}) do
    start_date = Timex.shift(Timex.today(), days: -30)
    date_range = Date.range(start_date, Timex.today())
    {"30days", date_range}
  end

  defp get_date_range(_) do
    get_date_range(%{"period" => "30days"})
  end

  defp calculate_bounce_rate(pageviews) do
    all_session_views = Enum.group_by(pageviews, fn pageview -> pageview.session_id end)
    |> Enum.map(fn {_session_id, views} -> Enum.count(views) end)
    one_page_sessions = all_session_views |> Enum.count(fn views -> views == 1 end)
    percentage = (one_page_sessions / Enum.count(all_session_views)) * 100
    "#{round(percentage)}%"
  end

  defp browser_name(ua) do
    case ua.client do
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      client -> client.name
    end
  end

  defp device_type(ua) do
    case ua.device do
      :unknown -> "unknown"
      device -> device.type
    end
  end

  defp operating_system(ua) do
    ua.os.name
  end
end
