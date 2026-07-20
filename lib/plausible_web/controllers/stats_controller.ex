defmodule PlausibleWeb.StatsController do
  use Plausible

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
  alias Plausible.Teams
  alias Plausible.Billing.Feature.SharedLinks

  plug(PlausibleWeb.Plugs.AuthorizeSiteAccess when action in [:stats])

  def stats(%{assigns: %{site: site}} = conn, _params) do
    site = Plausible.Repo.preload(site, :owners)
    site_role = conn.assigns[:site_role]
    current_user = conn.assigns[:current_user]
    stats_start_date = Plausible.Sites.stats_start_date(site)
    can_see_stats? = not Teams.locked?(site.team) or site_role == :super_admin
    demo = site.domain == "plausible.io"
    dogfood_page_path = if demo, do: "/#{site.domain}", else: "/:dashboard"

    consolidated_view? = Plausible.Sites.consolidated?(site)

    {exploration_journey_end_event, exploration_max_journey_steps} =
      on_ee(
        do:
          {Plausible.Stats.Exploration.Journey.Step.journey_end_event(),
           Plausible.Stats.Exploration.max_steps()},
        else: {"", 0}
      )

    consolidated_view_available? =
      on_ee(do: Plausible.ConsolidatedView.ok_to_display?(site.team), else: false)

    team_identifier = site.team.identifier

    {:ok, segments} = Plausible.Segments.get_all_for_site(site, site_role)
    segments = Enum.map(segments, &Plausible.Segments.to_response_map(&1, site))

    cond do
      consolidated_view? and not consolidated_view_available? and site_role != :super_admin ->
        redirect(conn, to: Routes.site_path(conn, :index))

      not can_see_stats? ->
        site = Plausible.Repo.preload(site, :owners)
        render(conn, "site_locked.html", site: site, dogfood_page_path: dogfood_page_path)

      true ->
        flags = get_flags(current_user, site)

        verify_installation? =
          ee?() and
            not is_nil(current_user) and
            not consolidated_view? and
            conn.params["verify_installation"] == "true"

        conn
        |> put_resp_header("x-robots-tag", "noindex, nofollow")
        |> render("stats.html",
          site: site,
          site_role: site_role,
          has_goals: Plausible.Sites.has_goals?(site),
          revenue_goals: list_revenue_goals(site),
          funnels: list_funnels(site),
          has_props: Plausible.Props.configured?(site),
          stats_start_date: stats_start_date,
          native_stats_start_date: NaiveDateTime.to_date(site.native_stats_start_at),
          title: title(conn, site),
          demo: demo,
          flags: flags,
          dbip?: dbip?(),
          segments: segments,
          load_dashboard_js: true,
          hide_footer?: if(ce?() || demo, do: false, else: site_role != :public),
          consolidated_view?: consolidated_view?,
          consolidated_view_available?: consolidated_view_available?,
          exploration_journey_end_event: exploration_journey_end_event,
          exploration_max_journey_steps: exploration_max_journey_steps,
          team_identifier: team_identifier,
          limited_to_segment_id: nil,
          connect_live_socket: verify_installation?,
          verify_installation?: verify_installation?,
          verification_session:
            PlausibleWeb.Live.Components.Verification.query_params()
            |> Map.new(&{&1, conn.params[&1]})
            |> Map.put("domain", site.domain)
        )
    end
  end

  on_ee do
    defp list_funnels(site) do
      Plausible.Funnels.list(site)
    end

    defp list_revenue_goals(site) do
      Plausible.Goals.list_revenue_goals(site)
    end
  else
    defp list_funnels(_site), do: []
    defp list_revenue_goals(_site), do: []
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
      {:ok, shared_link} ->
        if Plausible.Site.SharedLink.password_protected?(shared_link) do
          render_password_protected_shared_link(conn, shared_link)
        else
          render_shared_link(conn, shared_link)
        end

      {:error, :not_found} ->
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
      new_link_format =
        Routes.stats_path(conn, :shared_link, shared_link.site.domain, [], auth: slug)

      redirect(conn, to: new_link_format)
    else
      render_error(conn, 404)
    end
  end

  def shared_link(conn, _) do
    render_error(conn, 400)
  end

  def validate_shared_link_password(conn, shared_link) do
    with {:ok, token} <- Map.fetch(conn.req_cookies, shared_link_cookie_name(shared_link.slug)),
         {:ok, %{slug: token_slug}} <- Plausible.Auth.Token.verify_shared_link(token),
         true <- token_slug == shared_link.slug do
      {:ok, shared_link}
    else
      _e -> {:error, :unauthorized}
    end
  end

  defp render_password_protected_shared_link(conn, shared_link) do
    conn = Plug.Conn.fetch_cookies(conn)

    # discard untrustworthy return_to given from query params
    trimmed_query_string = conn.query_string |> omit_from_query_string("return_to")
    star_path_fragment = serialize_star_path_as_query_string_fragment(conn)

    # set valid return_to if star path is set
    query_string =
      [trimmed_query_string, star_path_fragment]
      |> Enum.filter(fn v -> is_binary(v) and String.length(v) > 0 end)
      |> Enum.join("&")

    case validate_shared_link_password(conn, shared_link) do
      {:ok, shared_link} ->
        render_shared_link(conn, shared_link)

      _ ->
        conn
        |> render("shared_link_password.html",
          link: shared_link,
          query_string: query_string,
          dogfood_page_path: "/share/:dashboard"
        )
    end
  end

  defp find_shared_link(domain, auth) do
    link_query =
      from(link in Plausible.Site.SharedLink,
        inner_join: site in assoc(link, :site),
        inner_join: team in assoc(site, :team),
        where: link.slug == ^auth,
        where: site.domain == ^domain,
        limit: 1,
        preload: [site: {site, team: team}]
      )

    case Repo.one(link_query) do
      %Plausible.Site.SharedLink{} = link ->
        {:ok, link}

      nil ->
        {:error, :not_found}
    end
  end

  def authenticate_shared_link(conn, %{"slug" => slug, "password" => password}) do
    shared_link =
      Repo.get_by(Plausible.Site.SharedLink, slug: slug)
      |> Repo.preload(:site)

    if shared_link do
      if Plausible.Auth.Password.match?(password, shared_link.password_hash) do
        token = Plausible.Auth.Token.sign_shared_link(slug)

        star_path = parse_star_path(conn)

        # The filter query params format used by the FE breaks when it passes through Phoenix / Plug.Conn decode/encode.
        # This function works around that by using the original query string.
        query_string_fragment =
          get_rest_of_query_string(conn)
          # omitted because return_to param was needed only for this function
          |> omit_from_query_string("return_to")
          # omitted because `auth: slug` query param is set definitively below
          |> omit_from_query_string("auth")

        conn
        |> put_resp_cookie(shared_link_cookie_name(slug), token)
        |> redirect(
          to:
            Routes.stats_path(
              conn,
              :shared_link,
              shared_link.site.domain,
              star_path,
              auth: slug
            ) <>
              query_string_fragment
        )
      else
        conn
        |> render("shared_link_password.html",
          link: shared_link,
          error: "Incorrect password. Please try again.",
          query_string: conn.query_string,
          dogfood_page_path: "/share/:dashboard"
        )
      end
    else
      render_error(conn, 404)
    end
  end

  defp serialize_star_path_as_query_string_fragment(conn) do
    star_path = conn.path_params["path"]

    if length(star_path) > 0 do
      # make the path start with a /
      # to be able to reject values that don't start with a /
      %{"return_to" => "/#{Enum.join(star_path, "/")}"} |> URI.encode_query()
    else
      nil
    end
  end

  defp parse_star_path(conn) do
    case conn.query_params["return_to"] do
      # omit prefix added in `serialize_star_path_as_query_string_fragment`
      "/" <> return_to ->
        return_to
        |> String.split("/")
        # disallow constructing links that navigate up
        |> Enum.filter(fn part -> part !== ".." end)

      _ ->
        []
    end
  end

  defp get_rest_of_query_string(conn) when conn.query_string in [nil, ""], do: ""

  defp get_rest_of_query_string(conn), do: "&#{conn.query_string}"

  defp omit_from_query_string(query_string, key) do
    query_string
    |> String.split("&")
    |> Enum.reject(fn key_and_value ->
      key_and_value == key || String.starts_with?(key_and_value, "#{key}=")
    end)
    |> Enum.join("&")
  end

  defp render_shared_link(conn, shared_link) do
    shared_links_feature_access? =
      SharedLinks.check_availability(shared_link.site.team) == :ok or
        shared_link.name in Plausible.Sites.shared_link_special_names()

    cond do
      Teams.locked?(shared_link.site.team) ->
        owners = Plausible.Repo.preload(shared_link.site, :owners)

        render(conn, "site_locked.html",
          owners: owners,
          site: shared_link.site,
          dogfood_page_path: "/share/:dashboard"
        )

      not shared_links_feature_access? ->
        owners = Plausible.Repo.preload(shared_link.site, :owners)

        render(conn, "site_locked.html",
          only_shared_link_access_missing?: true,
          owners: owners,
          site: shared_link.site,
          dogfood_page_path: "/share/:dashboard"
        )

      not Teams.locked?(shared_link.site.team) ->
        current_user = conn.assigns[:current_user]
        site_role = get_fallback_site_role(conn)
        shared_link = Plausible.Repo.preload(shared_link, :segment, site: [:owners])
        stats_start_date = Plausible.Sites.stats_start_date(shared_link.site)

        flags = get_flags(current_user, shared_link.site)

        {exploration_journey_end_event, exploration_max_journey_steps} =
          on_ee(
            do:
              {Plausible.Stats.Exploration.Journey.Step.journey_end_event(),
               Plausible.Stats.Exploration.max_steps()},
            else: {"", 0}
          )

        limited_to_segment_id =
          if Plausible.Site.SharedLink.limited_to_segment?(shared_link) do
            shared_link.segment.id
          else
            nil
          end

        segments =
          if is_nil(limited_to_segment_id) do
            {:ok, segments} = Plausible.Segments.get_all_for_site(shared_link.site, site_role)
            Enum.map(segments, &Plausible.Segments.to_response_map(&1, shared_link.site))
          else
            shared_link.segment
            |> Plausible.Segments.to_response_map(shared_link.site)
            |> List.wrap()
          end

        embedded? = conn.params["embed"] == "true"

        true = Plausible.Sites.regular?(shared_link.site)

        team_identifier = shared_link.site.team.identifier

        conn
        |> put_resp_header("x-robots-tag", "noindex, nofollow")
        |> delete_resp_header("x-frame-options")
        |> render("stats.html",
          site: shared_link.site,
          site_role: site_role,
          has_goals: Sites.has_goals?(shared_link.site),
          revenue_goals: list_revenue_goals(shared_link.site),
          funnels: list_funnels(shared_link.site),
          has_props: Plausible.Props.configured?(shared_link.site),
          stats_start_date: stats_start_date,
          native_stats_start_date: NaiveDateTime.to_date(shared_link.site.native_stats_start_at),
          title: title(conn, shared_link.site),
          demo: false,
          shared_link_auth: shared_link.slug,
          embedded: embedded?,
          background: conn.params["background"],
          theme: conn.params["theme"],
          flags: flags,
          dbip?: dbip?(),
          segments: segments,
          load_dashboard_js: true,
          hide_footer?: if(ce?(), do: embedded?, else: embedded? || site_role != :public),
          # no shared links for consolidated views
          consolidated_view?: false,
          consolidated_view_available?: false,
          exploration_journey_end_event: exploration_journey_end_event,
          exploration_max_journey_steps: exploration_max_journey_steps,
          team_identifier: team_identifier,
          limited_to_segment_id: limited_to_segment_id,
          verify_installation?: false,
          verification_session: %{}
        )
    end
  end

  defp get_fallback_site_role(conn),
    do: if(role = conn.assigns[:site_role], do: role, else: :public)

  defp shared_link_cookie_name(slug), do: "shared-link-" <> slug

  defp get_flags(user, site),
    do:
      []
      |> Enum.map(fn flag ->
        {flag, FunWithFlags.enabled?(flag, for: user) || FunWithFlags.enabled?(flag, for: site)}
      end)
      |> Map.new()

  defp dbip?() do
    on_ee do
      false
    else
      Plausible.Geo.database_type()
      |> to_string()
      |> String.starts_with?("DBIP")
    end
  end

  defp title(%{path_info: ["plausible.io"]}, _) do
    "Plausible Analytics: Live Demo"
  end

  defp title(_conn, site) do
    "Plausible · " <> site.domain
  end
end
