defmodule PlausibleWeb.StatsController do
  @moduledoc """
  This controller is responsible for rendering stats dashboards.

  The stats dashboards are currently the only part of the app that uses client-side
  rendering. Since the dashboards are heavily interactive, they are built with React
  which is an appropriate choice for highly interactive browser UIs.

  <div class="mermaid">
  sequenceDiagram
    Browser->>StatsController: GET /mydomain.com
    StatsController-->>Browser: StatsView.render("stats.html")
    Note left of Browser: ReactDom.render(Dashboard)

    Browser -) Api.StatsController: GET /api/stats/mydomain.com/top-stats
    Api.StatsController --) Browser: {"top_stats": [...]}
    Note left of Browser: TopStats.render()

    Browser -) Api.StatsController: GET /api/stats/mydomain.com/main-graph
    Api.StatsController --) Browser: [{"plot": [...], "labels": [...]}, ...]
    Note left of Browser: VisitorGraph.render()

    Browser -) Api.StatsController: GET /api/stats/mydomain.com/sources
    Api.StatsController --) Browser: [{"name": "Google", "visitors": 292150}, ...]
    Note left of Browser: Sources.render()

    Note over Browser,StatsController: And so on, for all reports in the viewport
  </div>

  This reasoning for this sequence is as follows:
    1. First paint is fast because it doesn't do any data aggregation yet - good UX
    2. The basic structure of the dashboard is rendered with spinners before reports are ready - good UX
    2. Rendering on the frontend allows for maximum interactivity. Re-rendering and re-fetching can be as granular as needed.
    3. Routing on the frontend allows the user to navigate the dashboard without reloading the page and losing context
    4. Rendering on the frontend allows caching results in the browser to reduce pressure on backends and storage
      3.1 No client-side caching has been implemented yet. This is still theoretical. See https://github.com/plausible/analytics/discussions/1278
      3.2 This is a big potential opportunity, because analytics data is mostly immutable. Clients can cache all historical data.
    5. Since frontend rendering & navigation is harder to build and maintain than regular server-rendered HTML, we don't use SPA-style rendering anywhere else
    .The only place currently where the benefits outweigh the costs is the dashboard.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Sites
  alias Plausible.Stats.{Query, Filters}
  alias PlausibleWeb.Api

  plug(PlausibleWeb.AuthorizeSiteAccess when action in [:stats, :csv_export])

  def stats(%{assigns: %{site: site}} = conn, _params) do
    stats_start_date = Plausible.Sites.stats_start_date(site)
    can_see_stats? = not Sites.locked?(site) or conn.assigns[:current_user_role] == :super_admin

    cond do
      stats_start_date && can_see_stats? ->
        demo = site.domain == PlausibleWeb.Endpoint.host()
        offer_email_report = get_session(conn, site.domain <> "_offer_email_report")

        conn
        |> assign(:skip_plausible_tracking, !demo)
        |> remove_email_report_banner(site)
        |> put_resp_header("x-robots-tag", "noindex, nofollow")
        |> render("stats.html",
          site: site,
          has_goals: Plausible.Sites.has_goals?(site),
          funnels: Plausible.Funnels.list(site),
          has_props: Plausible.Props.configured?(site),
          stats_start_date: stats_start_date,
          native_stats_start_date: NaiveDateTime.to_date(site.native_stats_start_at),
          title: title(conn, site),
          offer_email_report: offer_email_report,
          demo: demo,
          flags: get_flags(conn.assigns[:current_user]),
          is_dbip: is_dbip()
        )

      !stats_start_date && can_see_stats? ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("waiting_first_pageview.html", site: site)

      Sites.locked?(site) ->
        owner = Sites.owner_for(site)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("site_locked.html", owner: owner, site: site)
    end
  end

  @doc """
  The export is limited to 300 entries for other reports and 100 entries for pages because bigger result sets
  start causing failures. Since we request data like time on page or bounce_rate for pages in a separate query
  using the IN filter, it causes the requests to balloon in payload size.
  """
  def csv_export(conn, params) do
    if is_nil(params["interval"]) or Plausible.Stats.Interval.valid?(params["interval"]) do
      site = conn.assigns[:site]
      query = Query.from(site, params) |> Filters.add_prefix()

      metrics =
        if query.filters["event:goal"] do
          [:visitors]
        else
          [:visitors, :pageviews, :visits, :views_per_visit, :bounce_rate, :visit_duration]
        end

      graph = Plausible.Stats.timeseries(site, query, metrics)
      columns = [:date | metrics]

      column_headers =
        if query.filters["event:goal"] do
          [:date, :unique_conversions]
        else
          columns
        end

      visitors =
        Enum.map(graph, fn row -> Enum.map(columns, &row[&1]) end)
        |> (fn data -> [column_headers | data] end).()
        |> CSV.encode()
        |> Enum.join()

      filename =
        'Plausible export #{params["domain"]} #{Timex.format!(query.date_range.first, "{ISOdate} ")} to #{Timex.format!(query.date_range.last, "{ISOdate} ")}.zip'

      params = Map.merge(params, %{"limit" => "300", "csv" => "True", "detailed" => "True"})
      limited_params = Map.merge(params, %{"limit" => "100"})

      csvs = %{
        'sources.csv' => fn -> Api.StatsController.sources(conn, params) end,
        'utm_mediums.csv' => fn -> Api.StatsController.utm_mediums(conn, params) end,
        'utm_sources.csv' => fn -> Api.StatsController.utm_sources(conn, params) end,
        'utm_campaigns.csv' => fn -> Api.StatsController.utm_campaigns(conn, params) end,
        'utm_contents.csv' => fn -> Api.StatsController.utm_contents(conn, params) end,
        'utm_terms.csv' => fn -> Api.StatsController.utm_terms(conn, params) end,
        'pages.csv' => fn -> Api.StatsController.pages(conn, limited_params) end,
        'entry_pages.csv' => fn -> Api.StatsController.entry_pages(conn, params) end,
        'exit_pages.csv' => fn -> Api.StatsController.exit_pages(conn, limited_params) end,
        'countries.csv' => fn -> Api.StatsController.countries(conn, params) end,
        'regions.csv' => fn -> Api.StatsController.regions(conn, params) end,
        'cities.csv' => fn -> Api.StatsController.cities(conn, params) end,
        'browsers.csv' => fn -> Api.StatsController.browsers(conn, params) end,
        'operating_systems.csv' => fn -> Api.StatsController.operating_systems(conn, params) end,
        'devices.csv' => fn -> Api.StatsController.screen_sizes(conn, params) end,
        'conversions.csv' => fn -> Api.StatsController.conversions(conn, params) end,
        'prop_breakdown.csv' => fn -> Api.StatsController.all_props_breakdown(conn, params) end,
        'referrers.csv' => fn -> Api.StatsController.referrers(conn, params) end
      }

      csvs =
        if FunWithFlags.enabled?(:props, for: conn.assigns[:current_user]) do
          Map.put(csvs, 'custom_props.csv', fn ->
            Api.StatsController.all_custom_prop_values(conn, params)
          end)
        else
          csvs
        end

      csv_values =
        Map.values(csvs)
        |> Plausible.ClickhouseRepo.parallel_tasks()

      csvs =
        Map.keys(csvs)
        |> Enum.zip(csv_values)

      csvs = [{'visitors.csv', visitors} | csvs]

      {:ok, {_, zip_content}} = :zip.create(filename, csvs, [:memory])

      conn
      |> put_resp_content_type("application/zip")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> delete_resp_cookie("exporting")
      |> send_resp(200, zip_content)
    else
      conn
      |> send_resp(400, "")
      |> halt()
    end
  end

  @doc """
    Authorizes and renders a shared link:
    1. Shared link with no password protection: needs to just make sure the shared link entry is still
    in our database. This check makes sure shared link access can be revoked by the site admins. If the
    shared link exists, render it directly.

    2. Shared link with password protection: Same checks as without the password, but an extra step is taken to
    protect the page with a password. When the user passes the password challenge, a cookie is set with Plausible.Auth.Token.sign_shared_link().
    The cookie allows the user to access the dashboard for 24 hours without entering the password again.

    ### Backwards compatibility

    The URL format for shared links was changed in [this pull request](https://github.com/plausible/analytics/pull/752) in order
    to make the URLs easier to bookmark. The old format is supported along with the new in order to not break old links.

    See: https://plausible.io/docs/shared-links
  """
  def shared_link(conn, %{"domain" => domain, "auth" => auth}) do
    case find_shared_link(domain, auth) do
      {:password_protected, shared_link} ->
        render_password_protected_shared_link(conn, shared_link)

      {:unlisted, shared_link} ->
        render_shared_link(conn, shared_link)

      :not_found ->
        render_error(conn, 404)
    end
  end

  @old_format_deprecation_date ~N[2022-01-01 00:00:00]
  def shared_link(conn, %{"domain" => slug}) do
    shared_link =
      Repo.one(
        from(l in Plausible.Site.SharedLink,
          where: l.slug == ^slug and l.inserted_at < ^@old_format_deprecation_date,
          preload: :site
        )
      )

    if shared_link do
      new_link_format = Routes.stats_path(conn, :shared_link, shared_link.site.domain, auth: slug)
      redirect(conn, to: new_link_format)
    else
      render_error(conn, 404)
    end
  end

  def shared_link(conn, _) do
    render_error(conn, 400)
  end

  defp render_password_protected_shared_link(conn, shared_link) do
    with conn <- Plug.Conn.fetch_cookies(conn),
         {:ok, token} <- Map.fetch(conn.req_cookies, shared_link_cookie_name(shared_link.slug)),
         {:ok, %{slug: token_slug}} <- Plausible.Auth.Token.verify_shared_link(token),
         true <- token_slug == shared_link.slug do
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
  end

  defp find_shared_link(domain, auth) do
    link_query =
      from(link in Plausible.Site.SharedLink,
        inner_join: site in assoc(link, :site),
        where: link.slug == ^auth,
        where: site.domain == ^domain,
        limit: 1,
        preload: [site: site]
      )

    case Repo.one(link_query) do
      %Plausible.Site.SharedLink{password_hash: hash} = link when not is_nil(hash) ->
        {:password_protected, link}

      %Plausible.Site.SharedLink{} = link ->
        {:unlisted, link}

      nil ->
        :not_found
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
        |> put_resp_cookie(shared_link_cookie_name(slug), token)
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
    cond do
      !shared_link.site.locked ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> put_resp_header("x-robots-tag", "noindex, nofollow")
        |> delete_resp_header("x-frame-options")
        |> render("stats.html",
          site: shared_link.site,
          has_goals: Sites.has_goals?(shared_link.site),
          funnels: Plausible.Funnels.list(shared_link.site),
          has_props: Plausible.Props.configured?(shared_link.site),
          stats_start_date: shared_link.site.stats_start_date,
          native_stats_start_date: NaiveDateTime.to_date(shared_link.site.native_stats_start_at),
          title: title(conn, shared_link.site),
          offer_email_report: false,
          demo: false,
          skip_plausible_tracking: true,
          shared_link_auth: shared_link.slug,
          embedded: conn.params["embed"] == "true",
          background: conn.params["background"],
          theme: conn.params["theme"],
          flags: get_flags(conn.assigns[:current_user]),
          is_dbip: is_dbip()
        )

      Sites.locked?(shared_link.site) ->
        owner = Sites.owner_for(shared_link.site)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("site_locked.html", owner: owner, site: shared_link.site)
    end
  end

  defp remove_email_report_banner(conn, site) do
    if conn.assigns[:current_user] do
      delete_session(conn, site.domain <> "_offer_email_report")
    else
      conn
    end
  end

  defp shared_link_cookie_name(slug), do: "shared-link-" <> slug

  defp get_flags(user) do
    %{
      funnels: Plausible.Funnels.enabled_for?(user),
      props: FunWithFlags.enabled?(:props, for: user)
    }
  end

  defp is_dbip() do
    is_or_nil =
      if Application.get_env(:plausible, :is_selfhost) do
        if type = Plausible.Geo.database_type() do
          String.starts_with?(type, "DBIP")
        end
      end

    !!is_or_nil
  end

  defp title(%{path_info: ["plausible.io"]}, _) do
    "Plausible Analytics: Live Demo"
  end

  defp title(_conn, site) do
    "Plausible · " <> site.domain
  end
end
