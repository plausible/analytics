defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

  defp show_stats(conn, site) do
    demo = site.domain == "plausible.io"
    {conn, period_params} = fetch_period(conn, site)

    Plausible.Tracking.event(conn, "Site Analytics: Open", %{demo: demo})

    query = Stats.Query.from(site.timezone, period_params)

    plot = Stats.calculate_plot(site, query)
    labels = Stats.labels(site, query)

		conn
    |> assign(:skip_plausible_tracking, !demo)
    |> render("stats.html",
      plot: plot,
      labels: labels,
      pageviews: Stats.total_pageviews(site, query),
      unique_visitors: Stats.unique_visitors(site, query),
      top_referrers: Stats.top_referrers(site, query) |> Enum.map(&(referrer_link(site, &1))),
      top_pages: Stats.top_pages(site, query),
      top_screen_sizes: Stats.top_screen_sizes(site, query),
      countries: Stats.countries(site, query),
      browsers: Stats.browsers(site, query),
      operating_systems: Stats.operating_systems(site, query),
      site: site,
      period: period_params["period"] || "month",
      query: query,
      title: "Plausible · " <> site.domain
    )
  end

  defp referrer_link(site, {name, count}) do
    link = "/#{site.domain}/referrers/#{name}"
    {{:link, name, link}, count}
  end

  def stats(conn, %{"website" => website}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      user = conn.assigns[:current_user]
      if user && Plausible.Billing.needs_to_upgrade?(conn.assigns[:current_user]) do
        redirect(conn, to: "/billing/upgrade")
      else
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
      end
    else
      render_error(conn, 404)
    end
  end

  def referrers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      referrers = Stats.top_referrers(site, query, 100)

      render(conn, "referrers.html", layout: false, site: site, top_referrers: referrers)
    else
      render_error(conn, 404)
    end
  end

  def referrer_drilldown(conn, %{"domain" => domain, "referrer" => "Google"}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      {:ok, keywords} = Plausible.Stats.GoogleSearchConsole.fetch_queries(site.domain)
      {:ok, overall_performance} = Plausible.Stats.GoogleSearchConsole.fetch_totals(site.domain)
      total_visitors = Stats.visitors_from_referrer(site, query, "Google")
      max_clicks = Enum.max_by(keywords, fn kw -> kw["clicks"] end)["clicks"]
      render(conn, "google_referrer.html",
        layout: false,
        site: site,
        keywords: keywords,
        total_visitors: total_visitors,
        overall_performance: overall_performance,
        max_clicks: max_clicks
      )
    else
      render_error(conn, 404)
    end
  end

  def referrer_drilldown(conn, %{"domain" => domain, "referrer" => referrer}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      referrers = Stats.referrer_drilldown(site, query, referrer)

      render(conn, "referrer_drilldown.html", layout: false, site: site, referrers: referrers, referrer: referrer)
    else
      render_error(conn, 404)
    end
  end

  def pages(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      pages = Stats.top_pages(site, query, 100)

      render(conn, "pages.html", layout: false, site: site, top_pages: pages)
    else
      render_error(conn, 404)
    end
  end

  def countries(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      countries = Stats.countries(site, query, 100)

      render(conn, "countries.html", layout: false, site: site, countries: countries)
    else
      render_error(conn, 404)
    end
  end

  def operating_systems(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      operating_systems = Stats.operating_systems(site, query, 100)

      render(conn, "operating_systems.html", layout: false, site: site, operating_systems: operating_systems)
    else
      render_error(conn, 404)
    end
  end

  def browsers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, period_params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, period_params)
      browsers = Stats.browsers(site, query, 100)

      render(conn, "browsers.html", layout: false, site: site, browsers: browsers)
    else
      render_error(conn, 404)
    end
  end

  defp current_user_can_access?(_conn, %Plausible.Site{public: true}) do
    true
  end

  defp current_user_can_access?(conn, site) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Plausible.Sites.can_access?(user.id, site)
    end
  end

  # TODO: This should move to localStorage when stats page is AJAX'ified
  defp fetch_period(conn, site) do
    case conn.params["period"] do
      "custom" ->
        {conn, conn.params}
      p when p in ["day", "week", "month", "3mo"] ->
        saved_periods = get_session(conn, :saved_periods) || %{}
        {put_session(conn, :saved_periods, Map.merge(saved_periods, %{site.domain => p})), conn.params}
      _ ->
        saved_period = (get_session(conn, :saved_periods) || %{})[site.domain]

        if saved_period do
          {conn, %{"period" => saved_period}}
        else
          {conn, conn.params}
        end
    end
  end
end
