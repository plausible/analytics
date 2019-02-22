defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

  defp show_stats(conn, site) do
    Plausible.Tracking.event(conn, "Site Analytics: Open")
    {date_range, period, step_type} = get_date_range(site, conn.params)

    query = Stats.Query.new(
      date_range: date_range,
      step_type: step_type
    )

    plot = Stats.calculate_plot(site, query)
    labels = Stats.labels(site, query)

		conn
    |> assign(:skip_plausible_tracking, site.domain !== "plausible.io")
    |> render("stats.html",
      plot: plot,
      labels: labels,
      pageviews: Stats.total_pageviews(site, query),
      unique_visitors: Stats.unique_visitors(site, query),
      top_referrers: Stats.top_referrers(site, query),
      top_pages: Stats.top_pages(site, query),
      top_screen_sizes: Stats.top_screen_sizes(site, query),
      device_types: Stats.device_types(site, query),
      browsers: Stats.browsers(site, query),
      operating_systems: Stats.operating_systems(site, query),
      site: site,
      period: period,
      date_range: date_range,
      title: "Plausible · " <> site.domain
    )
  end

  def stats(conn, %{"website" => website}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      has_pageviews = Repo.exists?(
        from p in Plausible.Pageview,
        where: p.hostname == ^website
      )

      if has_pageviews do
        show_stats(conn, site)
      else
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("waiting_first_pageview.html", site: site)
      end
    else
      conn |> send_resp(404, "Website not found")
    end
  end

  defp current_user_can_access?(_conn, %Plausible.Site{domain: "plausible.io"}) do
    true
  end

  defp current_user_can_access?(conn, site) do
    case conn.assigns[:current_user] do
      nil -> false
      user ->
        user = user |> Repo.preload(:sites)

        Enum.any?(user.sites, fn user_site -> user_site == site end)
    end
  end

  defp get_date_range(site, %{"period" => "today"}) do
    date_range = Date.range(today(site), today(site))
    {date_range, "today","hour"}
  end

  defp get_date_range(site, %{"period" => "7days"}) do
    start_date = Timex.shift(today(site), days: -7)
    date_range = Date.range(start_date, today(site))
    {date_range, "7days" ,"date"}
  end

  defp get_date_range(site, %{"period" => "30days"}) do
    start_date = Timex.shift(today(site), days: -30)
    date_range = Date.range(start_date, today(site))
    {date_range, "30days" ,"date"}
  end

  defp get_date_range(_site, %{"period" => "custom", "from" => from, "to" => to}) do
    start_date = Date.from_iso8601!(from)
    end_date = Date.from_iso8601!(to)
    date_range = Date.range(start_date, end_date)
    {date_range, "custom" , "date"}
  end

  defp get_date_range(site, _) do
    get_date_range(site, %{"period" => "7days"})
  end

  defp today(site) do
    Timex.now(site.timezone) |> Timex.to_date
  end
end
