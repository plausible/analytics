defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller
  use Neatmetrics.Repo

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def normalize_referrer(pageview) do
    pageview.referrer
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
    |> String.replace_suffix("/", "")
  end

  def analytics(conn, %{"website" => website}) do
    end_date = Timex.today()
    start_date = Timex.shift(Timex.today(), days: -7)
    date_range = Date.range(start_date, end_date)

    pageviews = Repo.all(from p in Neatmetrics.Pageview, where: p.hostname == ^website)
    pageview_groups = Enum.group_by(pageviews, fn pageview -> NaiveDateTime.to_date(pageview.inserted_at) end)

    plot = Enum.map(date_range, fn day ->
      Enum.count(pageview_groups[day] || [])
    end)

    labels = Enum.map(date_range, fn date ->
      Timex.format!(date, "{D} {Mshort}")
    end)

    top_referrers = pageviews
    |> Enum.filter(fn pv -> pv.referrer && !String.contains?(pv.referrer, pv.hostname) end)
    |> Enum.map(&(normalize_referrer(&1)))
    |> Enum.group_by(&(&1))
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
      bounce_rate: "68%",
      average_session: "1:31",
      top_referrers: top_referrers,
      top_pages: top_pages,
      top_screen_sizes: top_screen_sizes,
      hostname: website
    )
  end
end
