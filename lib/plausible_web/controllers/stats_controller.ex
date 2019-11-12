defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

  defp referrer_link(site, {name, count}, query) do
    link = "/#{site.domain}/referrers/#{name}" <> PlausibleWeb.StatsView.query_params(query)
    {{:link, name, link}, count}
  end

  def stats(conn, %{"website" => website}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      user = conn.assigns[:current_user]
      if user && Plausible.Billing.needs_to_upgrade?(conn.assigns[:current_user]) do
        redirect(conn, to: "/billing/upgrade")
      else
        if Plausible.Sites.has_pageviews?(site) do
          offer_email_report = get_session(conn, site.domain <> "_offer_email_report")

          Plausible.Tracking.event(conn, "Site Analytics: Open", %{demo: site.domain == "plausible.io"})

          {conn, params} = fetch_period(conn, site)
          query = Stats.Query.from(site.timezone, params)
          current_visitors = Stats.current_visitors(site)
          has_goals = user && Plausible.Sites.has_goals?(site)

          conn
          |> assign(:skip_plausible_tracking, !site.public)
          |> put_session(site.domain <> "_offer_email_report", nil)
          |> render("stats.html",
            site: site,
            has_goals: has_goals,
            query: query,
            current_visitors: current_visitors,
            title: "Plausible · " <> site.domain,
            offer_email_report: offer_email_report
          )
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

  def browsers_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "browsers_preview.html",
        browsers: Stats.browsers(site, query),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def operating_systems_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "operating_systems_preview.html",
        operating_systems: Stats.operating_systems(site, query),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def screen_sizes_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "screen_sizes_preview.html",
        top_screen_sizes: Stats.top_screen_sizes(site, query),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def referrers_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "referrers_preview.html",
        top_referrers: Stats.top_referrers(site, query) |> Enum.map(&(referrer_link(site, &1, query))),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def pages_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "pages_preview.html",
        top_pages: Stats.top_pages(site, query),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def countries_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site && current_user_can_access?(conn, site) do
      render(conn,
        "countries_preview.html",
        top_countries: Stats.countries(site, query),
        site: site,
        query: query,
        layout: false
      )
    else
      render_error(conn, 404)
    end
  end

  def main_graph(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    plot_task = Task.async(fn -> Stats.calculate_plot(site, query) end)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {plot, labels, present_index} = Task.await(plot_task)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      pageviews: pageviews,
      unique_visitors: visitors,
      interval: query.step_type
    })
  end

  def compare(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)
    {pageviews, ""} = Integer.parse(conn.params["pageviews"])
    {unique_visitors, ""} = Integer.parse(conn.params["unique_visitors"])

    if site && current_user_can_access?(conn, site) do
      {change_pageviews, change_visitors} = Stats.compare_pageviews_and_visitors(site, query, {pageviews, unique_visitors})

      json(conn, %{
        change_pageviews: change_pageviews,
        change_visitors: change_visitors
      })
    end
  end

  def referrers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      referrers = Stats.top_referrers(site, query, 100)

      render(conn, "referrers.html", layout: false, site: site, top_referrers: referrers, query: query)
    else
      render_error(conn, 404)
    end
  end

  def referrer_drilldown(conn, %{"domain" => domain, "referrer" => "Google"}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
           |> Repo.preload(:google_auth)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      total_visitors = Stats.visitors_from_referrer(site, query, "Google")
      search_terms = if site.google_auth && site.google_auth.property do
         Plausible.Google.Api.fetch_stats(site.google_auth, query)
      end

      render(conn, "google_referrer.html",
        layout: false,
        site: site,
        search_terms: search_terms,
        total_visitors: total_visitors,
        query: query
      )
    else
      render_error(conn, 404)
    end
  end

  def referrer_drilldown(conn, %{"domain" => domain, "referrer" => referrer}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      referrers = Stats.referrer_drilldown(site, query, referrer)
      total_visitors = Stats.visitors_from_referrer(site, query, referrer)

      render(conn, "referrer_drilldown.html", layout: false, site: site, referrers: referrers, referrer: referrer, total_visitors: total_visitors, query: query)
    else
      render_error(conn, 404)
    end
  end

  def pages(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      pages = Stats.top_pages(site, query, 100)

      render(conn, "pages.html", layout: false, site: site, top_pages: pages)
    else
      render_error(conn, 404)
    end
  end

  def countries(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      countries = Stats.countries(site, query, 100)

      render(conn, "countries.html", layout: false, site: site, countries: countries)
    else
      render_error(conn, 404)
    end
  end

  def operating_systems(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      operating_systems = Stats.operating_systems(site, query, 100)

      render(conn, "operating_systems.html", layout: false, site: site, operating_systems: operating_systems)
    else
      render_error(conn, 404)
    end
  end

  def browsers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      browsers = Stats.browsers(site, query, 100)

      render(conn, "browsers.html", layout: false, site: site, browsers: browsers)
    else
      render_error(conn, 404)
    end
  end

  def current_visitors(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      json(conn, Stats.current_visitors(site))
    else
      render_error(conn, 404)
    end
  end

  def conversions_preview(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site && current_user_can_access?(conn, site) do
      {conn, params} = fetch_period(conn, site)
      query = Stats.Query.from(site.timezone, params)
      goals = Stats.goal_conversions(site, query)

      render(conn, "conversions_preview.html", layout: false, query: query, site: site, goals: goals)
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
      user -> Plausible.Sites.is_owner?(user.id, site)
    end
  end

  defp fetch_period(conn, site) do
    case conn.params["period"] do
      p when p in ["day", "month", "7d", "3mo", "6mo"] ->
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
