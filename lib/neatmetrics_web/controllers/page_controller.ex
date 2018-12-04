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

    top_pages = Enum.group_by(pageviews, &(&1.pathname))
    |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
    |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)

    top_screen_sizes = Enum.group_by(pageviews, &Neatmetrics.Pageview.screen_string/1)
    |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
    |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)

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
