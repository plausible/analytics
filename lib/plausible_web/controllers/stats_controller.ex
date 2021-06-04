defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats.Clickhouse, as: Stats
  alias Plausible.Stats.Query

  plug PlausibleWeb.AuthorizeStatsPlug when action in [:stats, :csv_export]

  def stats(%{assigns: %{site: site}} = conn, _params) do
    has_pageviews = Stats.has_pageviews?(site)

    cond do
      !site.locked && has_pageviews ->
        demo = site.domain == PlausibleWeb.Endpoint.host()
        offer_email_report = get_session(conn, site.domain <> "_offer_email_report")

        conn
        |> assign(:skip_plausible_tracking, !demo)
        |> remove_email_report_banner(site)
        |> put_resp_header("x-robots-tag", "noindex")
        |> render("stats.html",
          site: site,
          has_goals: Plausible.Sites.has_goals?(site),
          title: "Plausible · " <> site.domain,
          offer_email_report: offer_email_report,
          demo: demo
        )

      !site.locked && !has_pageviews ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("waiting_first_pageview.html", site: site)

      site.locked ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("site_locked.html", site: site)
    end
  end

  def csv_export(conn, %{"domain" => domain}) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, conn.params)

    metrics =
      if query.filters["event:name"] do
        ["visitors", "pageviews"]
      else
        ["visitors", "pageviews", "bounce_rate", "visit_duration"]
      end

    graph = Plausible.Stats.timeseries(site, query, metrics)

    headers = ["date" | metrics]

    csv_content =
      Enum.map(graph, fn row -> Enum.map(headers, &row[&1]) end)
      |> (fn data -> [headers | data] end).()
      |> CSV.encode()
      |> Enum.into([])
      |> Enum.join()

    filename =
      "Plausible export #{domain} #{Timex.format!(query.date_range.first, "{ISOdate} ")} to #{
        Timex.format!(query.date_range.last, "{ISOdate} ")
      }.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_content)
  end

  def shared_link(conn, %{"slug" => domain, "auth" => auth}) do
    shared_link =
      Repo.get_by(Plausible.Site.SharedLink, slug: auth)
      |> Repo.preload(:site)

    if shared_link && shared_link.site.domain == domain do
      if shared_link.password_hash do
        with conn <- Plug.Conn.fetch_cookies(conn),
             {:ok, token} <- Map.fetch(conn.req_cookies, "shared-link-token"),
             {:ok, _} <- Plausible.Auth.Token.verify_shared_link(token) do
          render_shared_link(conn, shared_link)
        else
          _e ->
            conn
            |> assign(:skip_plausible_tracking, true)
            |> render("shared_link_password.html",
              link: shared_link,
              layout: {PlausibleWeb.LayoutView, "focus.html"}
            )
        end
      else
        render_shared_link(conn, shared_link)
      end
    end
  end

  def shared_link(conn, %{"slug" => slug}) do
    shared_link =
      Repo.get_by(Plausible.Site.SharedLink, slug: slug)
      |> Repo.preload(:site)

    if shared_link do
      redirect(conn, to: "/share/#{URI.encode_www_form(shared_link.site.domain)}?auth=#{slug}")
    else
      render_error(conn, 404)
    end
  end

  def authenticate_shared_link(conn, %{"slug" => slug, "password" => password}) do
    shared_link =
      Repo.get_by(Plausible.Site.SharedLink, slug: slug)
      |> Repo.preload(:site)

    if shared_link do
      if Plausible.Auth.Password.match?(password, shared_link.password_hash) do
        token = Plausible.Auth.Token.sign_shared_link(slug)

        conn
        |> put_resp_cookie("shared-link-token", token)
        |> redirect(to: "/share/#{URI.encode_www_form(shared_link.site.domain)}?auth=#{slug}")
      else
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("shared_link_password.html",
          link: shared_link,
          error: "Incorrect password. Please try again.",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
      end
    else
      render_error(conn, 404)
    end
  end

  defp render_shared_link(conn, shared_link) do
    conn
    |> assign(:skip_plausible_tracking, true)
    |> put_resp_header("x-robots-tag", "noindex")
    |> delete_resp_header("x-frame-options")
    |> render("stats.html",
      site: shared_link.site,
      has_goals: Plausible.Sites.has_goals?(shared_link.site),
      title: "Plausible · " <> shared_link.site.domain,
      offer_email_report: false,
      demo: false,
      skip_plausible_tracking: true,
      shared_link_auth: shared_link.slug,
      embedded: conn.params["embed"] == "true",
      background: conn.params["background"],
      theme: conn.params["theme"]
    )
  end

  defp remove_email_report_banner(conn, site) do
    if conn.assigns[:current_user] do
      delete_session(conn, site.domain <> "_offer_email_report")
    else
      conn
    end
  end
end
