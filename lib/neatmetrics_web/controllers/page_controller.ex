defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def analytics(conn, %{"website" => website}) do
    end_date = Timex.today()
    start_date = Timex.shift(Timex.today(), days: -7)
    date_range = Date.range(start_date, end_date)

    pageviews = Neatmetrics.Repo.all(Neatmetrics.Pageview)
    pageview_groups = Enum.group_by(pageviews, fn pageview -> NaiveDateTime.to_date(pageview.inserted_at) end)

    plot = Enum.map(date_range, fn day ->
      Enum.count(pageview_groups[day] || [])
    end)

    labels = Enum.map(date_range, fn date ->
      formatted = Timex.format!(date, "{D} {Mshort}")
    end)

    top_referrers = [
      {"facebook", "1.2k"},
      {"google", "884"},
      {"third-place.com", "619"},
      {"direct", "176"},
      {"blog", "91"},
    ]

    top_pages = [
      {"/", "666"},
      {"/gigs/*", "457"},
      {"/gigs", "336"},
      {"/about", "87"},
      {"/login", "32"},
    ]

    top_screen_sizes = [
      {"365 x 667", "194"},
      {"1440 x 900", "126"},
      {"360 x 640", "97"},
      {"1366 x 768", "91"},
      {"1280 x 800", "90"},
    ]

    render(conn, "analytics.html",
      plot: plot,
      labels: labels,
      pageviews: Enum.count(pageviews),
      unique_visitors: "869",
      bounce_rate: "68%",
      average_session: "1:31",
      top_referrers: top_referrers,
      top_pages: top_pages,
      top_screen_sizes: top_screen_sizes
    )
  end
end
