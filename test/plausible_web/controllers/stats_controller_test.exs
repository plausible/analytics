defmodule PlausibleWeb.StatsControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo

  @react_container "div#stats-react-container"

  describe "GET /:domain - anonymous user" do
    test "public site - shows site stats", %{conn: conn} do
      site = new_site(public: true)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/#{site.domain}")
      resp = html_response(conn, 200)
      assert element_exists?(resp, @react_container)

      assert text_of_attr(resp, @react_container, "data-domain") == site.domain
      assert text_of_attr(resp, @react_container, "data-is-dbip") == "false"
      assert text_of_attr(resp, @react_container, "data-has-goals") == "false"
      assert text_of_attr(resp, @react_container, "data-conversions-opted-out") == "false"
      assert text_of_attr(resp, @react_container, "data-funnels-opted-out") == "false"
      assert text_of_attr(resp, @react_container, "data-props-opted-out") == "false"
      assert text_of_attr(resp, @react_container, "data-props-available") == "true"
      assert text_of_attr(resp, @react_container, "data-site-segments-available") == "true"
      assert text_of_attr(resp, @react_container, "data-funnels-available") == "true"
      assert text_of_attr(resp, @react_container, "data-exploration-available") == "true"
      assert text_of_attr(resp, @react_container, "data-has-props") == "false"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "public"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "null"
      assert text_of_attr(resp, @react_container, "data-embedded") == ""
      assert text_of_attr(resp, @react_container, "data-is-consolidated-view") == "false"
      assert text_of_attr(resp, @react_container, "data-consolidated-view-available") == "false"
      assert text_of_attr(resp, @react_container, "data-team-identifier") == site.team.identifier

      assert "noindex, nofollow" ==
               resp
               |> find("meta[name=robots]")
               |> text_of_attr("content")

      assert to_string(Plausible.InternalStatsApiVersion.api_version()) ==
               resp
               |> find("meta[name=x-api-version]")
               |> text_of_attr("content")

      assert text_of_element(resp, "title") == "Plausible · #{site.domain}"
    end

    test "public site - all segments (personal or site) are stuffed into dataset, without their owner_id and owner_name",
         %{conn: conn} do
      user = new_user()
      site = new_site(owner: user, public: true)

      populate_stats(site, [build(:pageview)])

      emea_site_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "EMEA region"
        )

      foo_personal_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :personal,
          name: "FOO"
        )

      conn = get(conn, "/#{site.domain}")
      resp = html_response(conn, 200)
      assert element_exists?(resp, @react_container)

      assert text_of_attr(resp, @react_container, "data-segments") ==
               Jason.encode!([
                 Plausible.Segments.to_response_map(
                   %{foo_personal_segment | owner_id: nil},
                   site
                 ),
                 Plausible.Segments.to_response_map(%{emea_site_segment | owner_id: nil}, site)
               ])
    end

    @tag :ee_only
    test "plausible.io live demo - shows site stats, header and footer", %{conn: conn} do
      site = new_site(domain: "plausible.io", public: true)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/#{site.domain}")
      resp = html_response(conn, 200)
      assert element_exists?(resp, @react_container)

      assert "index, nofollow" ==
               resp
               |> find("meta[name=robots]")
               |> text_of_attr("content")

      assert text_of_element(resp, "title") == "Plausible Analytics: Live Demo"
      assert resp =~ "Login"
      assert resp =~ "You just saw how Plausible tracks plausible.io"
      assert resp =~ "Start free trial"
      assert resp =~ "See pricing"
      assert resp =~ "Getting started"
    end

    test "public site - redirect to /login when no stats because verification requires it", %{
      conn: conn
    } do
      new_site(domain: "some-other-public-site.io", public: true)

      conn = get(conn, conn |> get("/some-other-public-site.io") |> redirected_to())

      assert redirected_to(conn) ==
               Routes.auth_path(conn, :login_form,
                 return_to: "/some-other-public-site.io/verification"
               )
    end

    test "public site - no stats with skip_to_dashboard", %{
      conn: conn
    } do
      new_site(domain: "some-other-public-site.io", public: true)

      conn = get(conn, "/some-other-public-site.io?skip_to_dashboard=true")
      resp = html_response(conn, 200)

      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
    end

    test "can not view stats of a private website", %{conn: conn} do
      _ = insert(:user)
      conn = get(conn, "/test-site.com")
      assert html_response(conn, 404) =~ "There's nothing here"
    end
  end

  describe "GET /:domain - as a logged in user" do
    setup [:create_user, :log_in, :create_site]

    test "can view stats of a website I've created", %{conn: conn, site: site, user: user} do
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "owner"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "#{user.id}"
    end

    test "can view stats of a website I've created, enforcing pageviews check skip", %{
      conn: conn,
      site: site
    } do
      resp = conn |> get(conn |> get("/" <> site.domain) |> redirected_to()) |> html_response(200)
      refute text_of_attr(resp, @react_container, "data-logged-in") == "true"

      resp = conn |> get("/" <> site.domain <> "?skip_to_dashboard=true") |> html_response(200)
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
    end

    on_ee do
      test "can't see exploration funnel UI if funnels feature unavailable", %{
        conn: conn,
        site: site,
        user: user
      } do
        subscribe_to_growth_plan(user)
        populate_stats(site, [build(:pageview)])
        conn = get(conn, "/" <> site.domain)
        resp = html_response(conn, 200)
        assert text_of_attr(resp, @react_container, "data-exploration-available") == "false"
      end

      test "can see exploration funnel UI on trial", %{conn: conn, site: site} do
        populate_stats(site, [build(:pageview)])
        conn = get(conn, "/" <> site.domain)
        resp = html_response(conn, 200)
        assert text_of_attr(resp, @react_container, "data-exploration-available") == "true"
      end

      test "can see exploration funnel UI past trial with funnels feature enabled", %{
        conn: conn,
        site: site,
        user: user
      } do
        populate_stats(site, [build(:pageview)])

        site.team
        |> Plausible.Teams.Team.end_trial()
        |> Plausible.Repo.update!()

        subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.Funnels])

        conn = get(conn, "/" <> site.domain)
        resp = html_response(conn, 200)
        assert text_of_attr(resp, @react_container, "data-exploration-available") == "true"
      end
    end

    on_ee do
      test "first view of a consolidated dashboard sets stats_start_date and native_stats_start_at according to native_stats_start_at of the earliest team site",
           %{
             conn: conn,
             site: site,
             user: user
           } do
        team = team_of(user)
        now = NaiveDateTime.utc_now(:second)
        ten_days_ago = NaiveDateTime.add(now, -10, :day)
        twenty_days_ago = NaiveDateTime.add(now, -20, :day)

        site
        |> Plausible.Site.set_native_stats_start_at(ten_days_ago)
        |> Plausible.Repo.update!()

        new_site(team: team, native_stats_start_at: twenty_days_ago)
        cv = new_consolidated_view(team)

        conn = get(conn, "/" <> cv.domain)
        resp = html_response(conn, 200)

        assert text_of_attr(resp, @react_container, "data-domain") == cv.domain
        assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
        assert text_of_attr(resp, @react_container, "data-current-user-role") == "owner"
        assert text_of_attr(resp, @react_container, "data-current-user-id") == "#{user.id}"

        cv = Plausible.Repo.reload(cv)
        assert cv.stats_start_date == NaiveDateTime.to_date(twenty_days_ago)
        assert cv.native_stats_start_at == twenty_days_ago
      end

      test "does not redirect consolidated views to verification", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)
        new_site(owner: user)
        cv = user |> team_of() |> new_consolidated_view()

        conn = get(conn, "/" <> cv.domain)
        resp = html_response(conn, 200)

        assert text_of_attr(resp, @react_container, "data-domain") == cv.domain
        assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
        assert text_of_attr(resp, @react_container, "data-current-user-role") == "owner"
        assert text_of_attr(resp, @react_container, "data-current-user-id") == "#{user.id}"
      end

      test "redirects to /sites if for some reason ineligible anymore", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)
        new_site(owner: user)
        cv = user |> team_of() |> new_consolidated_view()

        user
        |> team_of()
        |> Plausible.Teams.Team.end_trial()
        |> Plausible.Repo.update!()

        conn = get(conn, "/" <> cv.domain)
        assert redirected_to(conn, 302) == "/sites"
      end
    end

    @tag :ee_only
    test "header, stats are shown; footer is not shown", %{conn: conn, site: site, user: user} do
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ user.name
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
      refute resp =~ "Getting started"
    end

    @tag :ce_build_only
    test "header, stats, footer are shown", %{conn: conn, site: site, user: user} do
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ user.name
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
      assert resp =~ "Getting started"
    end

    test "shows locked page if site is locked", %{conn: conn, user: user} do
      locked_site = new_site(owner: user)
      locked_site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      conn = get(conn, "/" <> locked_site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "Your dashboard is unavailable"
      assert resp =~ "Upgrade to the appropriate plan to restore access"
    end

    test "shows locked page if site is locked for billing role", %{conn: conn, user: user} do
      other_user = new_user()
      locked_site = new_site(owner: other_user)
      locked_site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      add_member(team_of(other_user), user: user, role: :billing)

      conn = get(conn, "/" <> locked_site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "Your dashboard is unavailable"
      assert resp =~ "Upgrade to the appropriate plan to restore access"
    end

    test "shows locked page if site is locked for viewer role", %{conn: conn, user: user} do
      other_user = new_user()
      locked_site = new_site(owner: other_user)
      locked_site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      add_member(team_of(other_user), user: user, role: :viewer)

      conn = get(conn, "/" <> locked_site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "Your dashboard is unavailable"
      refute resp =~ "Upgrade to the appropriate plan to restore access"
      assert resp =~ "The owner of this site must upgrade their subscription plan"
    end

    test "shows locked page for anonymous" do
      locked_site = new_site(public: true)
      locked_site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      conn = get(build_conn(), "/" <> locked_site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "Your dashboard is unavailable"
      assert resp =~ "You can check back later or contact the site owner"
    end

    test "can not view stats of someone else's website", %{conn: conn} do
      site = new_site()
      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 404) =~ "There's nothing here"
    end

    test "does not show CRM link to the site", %{conn: conn, site: site} do
      conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())

      refute html_response(conn, 200) =~ "/cs/sites"
    end

    test "all segments (personal or site) are stuffed into dataset, with their associated owner_id and owner_name",
         %{conn: conn, site: site, user: user} do
      populate_stats(site, [build(:pageview)])

      emea_site_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "EMEA region"
        )

      foo_personal_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :personal,
          name: "FOO"
        )

      conn = get(conn, "/#{site.domain}")
      resp = html_response(conn, 200)
      assert element_exists?(resp, @react_container)

      assert text_of_attr(resp, @react_container, "data-segments") ==
               Jason.encode!([
                 Plausible.Segments.to_response_map(foo_personal_segment, site),
                 Plausible.Segments.to_response_map(emea_site_segment, site)
               ])
    end
  end

  describe "GET /:domain - as a super admin" do
    @describetag :ee_only
    setup [:create_user, :make_user_super_admin, :log_in]

    test "can view a private dashboard with stats", %{conn: conn, user: user} do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "stats-react-container"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "super_admin"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "#{user.id}"
    end

    test "can enter verification when site is without stats", %{conn: conn} do
      site = new_site()

      conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())
      assert html_response(conn, 200) =~ "Verifying your installation"
    end

    test "can view a private locked dashboard with stats", %{conn: conn} do
      user = new_user()
      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "This dashboard is actually locked"
    end

    test "can view private locked verification without stats", %{conn: conn} do
      user = new_user()
      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

      conn = get(conn, conn |> get("/#{site.domain}") |> redirected_to())
      assert html_response(conn, 200) =~ "Verifying your installation"
    end

    test "can view a locked public dashboard", %{conn: conn} do
      site = new_site(public: true)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "This dashboard is actually locked"
    end

    on_ee do
      test "shows CRM link to the site", %{conn: conn} do
        site = new_site()
        conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())

        assert html_response(conn, 200) =~
                 Routes.customer_support_site_path(PlausibleWeb.Endpoint, :show, site.id)
      end
    end
  end

  defp make_user_super_admin(%{user: user}) do
    Application.put_env(:plausible, :super_admin_user_ids, [user.id])
  end

  describe "GET /share/:domain?auth=:auth" do
    test "prompts a password for a password-protected link", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = get(conn, "/share/#{site.domain}?auth=#{link.slug}")
      assert response(conn, 200) =~ "Enter password"
    end

    test "if the shared link is not protected with a password, passes user immediately to dashboard",
         %{
           conn: conn
         } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      resp = html_response(conn, 200)
      assert resp =~ "stats-react-container"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "null"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "public"
    end

    test "if the shared link is limited to a segment, only that segment is stuffed into data-segments",
         %{
           conn: conn
         } do
      site = new_site(domain: "test-site.com")
      emea_site_segment = insert(:segment, name: "EMEA", site: site, type: :site)
      apac_site_segment = insert(:segment, name: "APAC", site: site, type: :site)
      link = insert(:shared_link, site: site, segment: emea_site_segment)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      resp = html_response(conn, 200)
      assert resp =~ "stats-react-container"

      assert text_of_attr(resp, @react_container, "data-limited-to-segment-id") ==
               "#{emea_site_segment.id}"

      assert text_of_attr(resp, @react_container, "data-segments") ==
               emea_site_segment
               |> Plausible.Segments.to_response_map(site)
               |> List.wrap()
               |> Jason.encode!()

      refute resp =~ apac_site_segment.name

      assert text_of_attr(resp, @react_container, "data-current-user-role") == "public"
    end

    test "footer and header are shown when accessing shared link dashboard", %{
      conn: conn
    } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      resp = html_response(conn, 200)
      assert resp =~ "stats-react-container"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "null"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "public"
      assert resp =~ "Login"
      assert resp =~ "Getting started"
    end

    test "returns page with X-Frame-Options disabled so it can be embedded in an iframe", %{
      conn: conn
    } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      resp = html_response(conn, 200)
      assert text_of_attr(resp, @react_container, "data-embedded") == "false"
      assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []
    end

    test "returns page embedded page", %{
      conn: conn
    } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}&embed=true")
      resp = html_response(conn, 200)
      assert text_of_attr(resp, @react_container, "data-embedded") == "true"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
      assert text_of_attr(resp, @react_container, "data-current-user-id") == "null"
      assert text_of_attr(resp, @react_container, "data-current-user-role") == "public"
      assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []
    end

    test "does not show header, does not show footer on embedded pages", %{conn: conn} do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}&embed=true")
      resp = html_response(conn, 200)
      assert text_of_attr(resp, @react_container, "data-embedded") == "true"
      refute resp =~ "Login"
      refute resp =~ "Getting started"
    end

    test "shows locked page if page is locked", %{conn: conn} do
      site = new_site(domain: "test-site.com")
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")

      assert html_response(conn, 200) =~ "Your dashboard is unavailable"
      refute String.contains?(html_response(conn, 200), "Back to my sites")
    end

    test "shows locked page if shared link is locked due to insufficient team subscription", %{
      conn: conn
    } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      insert(:starter_subscription, team: site.team)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")

      assert html_response(conn, 200) =~ "Shared link unavailable"
      refute String.contains?(html_response(conn, 200), "Back to my sites")
    end

    for special_name <- Plausible.Sites.shared_link_special_names() do
      test "shows dashboard if team subscription insufficient but shared link name is '#{special_name}'",
           %{conn: conn} do
        site = new_site(domain: "test-site.com")
        link = insert(:shared_link, site: site, name: unquote(special_name))

        insert(:starter_subscription, team: site.team)

        html =
          conn
          |> get("/share/test-site.com/?auth=#{link.slug}")
          |> html_response(200)

        assert element_exists?(html, @react_container)
        refute html =~ "Shared Link Unavailable"
      end
    end

    test "renders 404 not found when no auth parameter supplied", %{conn: conn} do
      conn = get(conn, "/share/example.com")
      assert response(conn, 404) =~ "nothing here"
    end

    test "renders 404 not found when non-existent auth parameter is supplied", %{conn: conn} do
      conn = get(conn, "/share/example.com?auth=bad-token")
      assert response(conn, 404) =~ "nothing here"
    end

    test "renders 404 not found when auth parameter for another site is supplied", %{conn: conn} do
      site1 = insert(:site, domain: "test-site-1.com")
      site2 = insert(:site, domain: "test-site-2.com")
      site1_link = insert(:shared_link, site: site1)

      conn = get(conn, "/share/#{site2.domain}/?auth=#{site1_link.slug}")
      assert response(conn, 404) =~ "nothing here"
    end

    test "all segments (personal or site) are stuffed into dataset, without their owner_id and owner_name",
         %{conn: conn} do
      user = new_user()
      site = new_site(domain: "test-site.com", owner: user)
      link = insert(:shared_link, site: site)

      emea_site_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "EMEA region"
        )

      foo_personal_segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :personal,
          name: "FOO"
        )

      conn = get(conn, "/share/#{site.domain}/?auth=#{link.slug}")
      resp = html_response(conn, 200)

      assert text_of_attr(resp, @react_container, "data-segments") ==
               Jason.encode!([
                 Plausible.Segments.to_response_map(
                   %{foo_personal_segment | owner_id: nil},
                   site
                 ),
                 Plausible.Segments.to_response_map(%{emea_site_segment | owner_id: nil}, site)
               ])
    end
  end

  describe "GET /share/:slug - backwards compatibility" do
    test "it redirects to new shared link format for historical links", %{conn: conn} do
      site = insert(:site, domain: "test-site.com")
      site_link = insert(:shared_link, site: site, inserted_at: ~N[2021-12-31 00:00:00])

      conn = get(conn, "/share/#{site_link.slug}")
      assert redirected_to(conn, 302) == "/share/#{site.domain}/?auth=#{site_link.slug}"
    end

    test "it does nothing for newer links", %{conn: conn} do
      site = insert(:site, domain: "test-site.com")
      site_link = insert(:shared_link, site: site, inserted_at: ~N[2022-01-01 00:00:00])

      conn = get(conn, "/share/#{site_link.slug}")
      assert response(conn, 404) =~ "nothing here"
    end
  end

  describe "POST /share/:slug/authenticate" do
    test "logs anonymous user in with correct password", %{conn: conn} do
      site = new_site(domain: "test-site.com")

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = post(conn, "/share/#{link.slug}/authenticate", %{password: "password"})
      assert redirected_to(conn, 302) == "/share/#{site.domain}/?auth=#{link.slug}"

      conn = get(conn, "/share/#{site.domain}?auth=#{link.slug}")
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "shows form again with wrong password", %{conn: conn} do
      site = insert(:site, domain: "test-site.com")

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = post(conn, "/share/#{link.slug}/authenticate", %{password: "WRONG!"})
      assert html_response(conn, 200) =~ "Enter password"
    end

    test "only gives access to the correct dashboard", %{conn: conn} do
      site = new_site(domain: "test-site.com")
      site2 = new_site(domain: "test-site2.com")

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      link2 =
        insert(:shared_link,
          site: site2,
          password_hash: Plausible.Auth.Password.hash("password1")
        )

      conn = post(conn, "/share/#{link.slug}/authenticate", %{password: "password"})
      assert redirected_to(conn, 302) == "/share/#{site.domain}/?auth=#{link.slug}"

      conn = get(conn, "/share/#{site2.domain}?auth=#{link2.slug}")
      assert html_response(conn, 200) =~ "Enter password"
    end

    test "preserves query parameters during password authentication", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      filters = "f=is,country,EE&l=EE,Estonia&f=is,browser,Firefox"

      conn =
        get(
          conn,
          "/share/#{URI.encode_www_form(site.domain)}?auth=#{link.slug}&#{filters}"
        )

      assert html_response(conn, 200) =~ "Enter password"
      html = html_response(conn, 200)

      expected_action_string =
        "/share/#{URI.encode_www_form(link.slug)}/authenticate?auth=#{link.slug}&#{filters}"

      assert text_of_attr(html, "form", "action") == expected_action_string

      conn =
        post(
          conn,
          expected_action_string,
          %{password: "WRONG!"}
        )

      html = html_response(conn, 200)
      assert html =~ "Enter password"
      assert html =~ "Incorrect password"

      assert text_of_attr(html, "form", "action") == expected_action_string

      conn =
        post(
          conn,
          expected_action_string,
          %{password: "password"}
        )

      expected_redirect =
        "/share/#{URI.encode_www_form(site.domain)}/?auth=#{link.slug}&#{filters}"

      assert redirected_to(conn, 302) == expected_redirect

      conn = get(conn, expected_redirect)
      assert html_response(conn, 200) =~ "stats-react-container"
    end
  end

  test "handles return_to during password authentication", %{conn: conn} do
    site = new_site()

    link =
      insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

    filters = "f=is,country,EE&l=EE,Estonia&f=is,browser,Firefox"

    deep_path = "/filter/source"

    conn =
      get(
        conn,
        "/share/#{URI.encode_www_form(site.domain)}#{deep_path}?auth=#{link.slug}&#{filters}"
      )

    assert html_response(conn, 200) =~ "Enter password"
    html = html_response(conn, 200)

    expected_action_string =
      "/share/#{link.slug}/authenticate?auth=#{link.slug}&#{filters}&#{URI.encode_query(%{"return_to" => deep_path})}"

    assert text_of_attr(html, "form", "action") == expected_action_string

    conn =
      post(
        conn,
        expected_action_string,
        %{password: "password"}
      )

    assert redirected_to(conn, 302) ==
             "/share/#{URI.encode_www_form(site.domain)}#{deep_path}?auth=#{link.slug}&#{filters}"
  end

  test "return_to from query_params is discarded", %{conn: conn} do
    site = new_site()

    link =
      insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

    conn =
      get(
        conn,
        "/share/#{URI.encode_www_form(site.domain)}/pages?auth=#{link.slug}&return_to=%2Ffoobar"
      )

    assert html_response(conn, 200) =~ "Enter password"
    html = html_response(conn, 200)

    expected_action_string =
      "/share/#{link.slug}/authenticate?auth=#{link.slug}&return_to=%2Fpages"

    assert text_of_attr(html, "form", "action") == expected_action_string

    conn =
      post(
        conn,
        expected_action_string,
        %{password: "password"}
      )

    assert redirected_to(conn, 302) ==
             "/share/#{URI.encode_www_form(site.domain)}/pages?auth=#{link.slug}"
  end

  test "return_to doesn't allow navigating out of dashboard context", %{conn: conn} do
    site = new_site()

    link =
      insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

    deep_path = "/../../settings/api-keys"
    cleaned_deep_path = "/settings/api-keys"

    conn =
      get(
        conn,
        "/share/#{URI.encode_www_form(site.domain)}#{deep_path}?auth=#{link.slug}&theme=dark"
      )

    assert html_response(conn, 200) =~ "Enter password"
    html = html_response(conn, 200)

    expected_action_string =
      "/share/#{link.slug}/authenticate?auth=#{link.slug}&theme=dark&#{URI.encode_query(%{"return_to" => deep_path})}"

    assert text_of_attr(html, "form", "action") == expected_action_string

    conn =
      post(
        conn,
        expected_action_string,
        %{password: "password"}
      )

    assert redirected_to(conn, 302) ==
             "/share/#{URI.encode_www_form(site.domain)}#{cleaned_deep_path}?auth=#{link.slug}&theme=dark"
  end

  describe "dogfood tracking" do
    @describetag :ee_only

    test "does not set domain_to_replace on live demo dashboard", %{conn: conn} do
      site = new_site(domain: "plausible.io", public: true)
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/#{site.domain}")
      script_params = html_response(conn, 200) |> get_script_params()

      assert %{
               "location_override" => nil,
               "domain_to_replace" => nil
             } = script_params
    end

    test "sets domain_to_replace on any other dashboard", %{conn: conn} do
      site = new_site(domain: "öö.ee", public: true)
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/#{site.domain}")
      script_params = html_response(conn, 200) |> get_script_params()

      assert %{
               "location_override" => nil,
               "domain_to_replace" => "%C3%B6%C3%B6.ee"
             } = script_params
    end

    test "sets domain_to_replace on live demo shared link", %{conn: conn} do
      site = new_site(domain: "plausible.io", public: true)
      link = insert(:shared_link, site: site)

      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/share/#{site.domain}/?auth=#{link.slug}")
      script_params = html_response(conn, 200) |> get_script_params()

      assert %{
               "location_override" => nil,
               "domain_to_replace" => "plausible.io"
             } = script_params
    end

    test "sets location_override on a locked dashboard", %{conn: conn} do
      locked_site = new_site(public: true)
      locked_site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

      conn = get(conn, "/" <> locked_site.domain)
      html = html_response(conn, 200)

      script_params = html |> get_script_params()

      assert html =~ "Your dashboard is unavailable"
      assert script_params["location_override"] == PlausibleWeb.Endpoint.url() <> "/:dashboard"
    end

    test "sets location_override on a locked shared link", %{conn: conn} do
      locked_site = new_site()
      link = insert(:shared_link, site: locked_site)

      insert(:starter_subscription, team: locked_site.team)

      conn = get(conn, "/share/#{locked_site.domain}/?auth=#{link.slug}")
      html = html_response(conn, 200)

      script_params = get_script_params(html)

      assert html =~ "Shared link unavailable"

      assert script_params["location_override"] ==
               PlausibleWeb.Endpoint.url() <> "/share/:dashboard"
    end

    test "sets location_override on shared_link_password.html", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = get(conn, "/share/#{site.domain}?auth=#{link.slug}")
      html = html_response(conn, 200)

      script_params = get_script_params(html)

      assert html =~ "Enter password"

      assert script_params["location_override"] ==
               PlausibleWeb.Endpoint.url() <> "/share/:dashboard"
    end
  end

  defp get_script_params(html) do
    html
    |> find("#dogfood-script")
    |> text_of_attr("data-script-params")
    |> JSON.decode!()
  end
end
