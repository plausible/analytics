defmodule PlausibleWeb.StatsControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Plausible.Teams.Test
  import Plausible.Test.Support.HTML

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
      assert text_of_attr(resp, @react_container, "data-funnels-available") == "true"
      assert text_of_attr(resp, @react_container, "data-has-props") == "false"
      assert text_of_attr(resp, @react_container, "data-logged-in") == "false"
      assert text_of_attr(resp, @react_container, "data-embedded") == ""

      [{"div", attrs, _}] = find(resp, @react_container)
      assert Enum.all?(attrs, fn {k, v} -> is_binary(k) and is_binary(v) end)

      assert ["noindex, nofollow"] ==
               resp
               |> find("meta[name=robots]")
               |> Floki.attribute("content")

      assert text_of_element(resp, "title") == "Plausible · #{site.domain}"
    end

    test "plausible.io live demo - shows site stats", %{conn: conn} do
      site = new_site(domain: "plausible.io", public: true)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/#{site.domain}")
      resp = html_response(conn, 200)
      assert element_exists?(resp, @react_container)

      assert ["index, nofollow"] ==
               resp
               |> find("meta[name=robots]")
               |> Floki.attribute("content")

      assert text_of_element(resp, "title") == "Plausible Analytics: Live Demo"
    end

    test "public site - redirect to /login when no stats because verification requires it", %{
      conn: conn
    } do
      new_site(domain: "some-other-public-site.io", public: true)

      conn = get(conn, conn |> get("/some-other-public-site.io") |> redirected_to())
      assert redirected_to(conn) == Routes.auth_path(conn, :login_form)
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

    test "can view stats of a website I've created", %{conn: conn, site: site} do
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert text_of_attr(resp, @react_container, "data-logged-in") == "true"
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

    test "shows locked page if page is locked", %{conn: conn, user: user} do
      locked_site = new_site(locked: true, owner: user)
      conn = get(conn, "/" <> locked_site.domain)
      assert html_response(conn, 200) =~ "Dashboard locked"
    end

    test "can not view stats of someone else's website", %{conn: conn} do
      site = new_site()
      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 404) =~ "There's nothing here"
    end

    test "does not show CRM link to the site", %{conn: conn, site: site} do
      conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())
      refute html_response(conn, 200) =~ "/crm/sites/site/#{site.id}"
    end
  end

  describe "GET /:domain - as a super admin" do
    @describetag :ee_only
    setup [:create_user, :make_user_super_admin, :log_in]

    test "can view a private dashboard with stats", %{conn: conn} do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "can enter verification when site is without stats", %{conn: conn} do
      site = new_site()

      conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())
      assert html_response(conn, 200) =~ "Verifying your installation"
    end

    test "can view a private locked dashboard with stats", %{conn: conn} do
      user = new_user()
      site = new_site(locked: true, owner: user)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)
      assert resp =~ "This dashboard is actually locked"

      [{"div", attrs, _}] = find(resp, @react_container)
      assert Enum.all?(attrs, fn {k, v} -> is_binary(k) and is_binary(v) end)
    end

    test "can view private locked verification without stats", %{conn: conn} do
      user = new_user()
      site = new_site(locked: true, owner: user)

      conn = get(conn, conn |> get("/#{site.domain}") |> redirected_to())
      assert html_response(conn, 200) =~ "Verifying your installation"
    end

    test "can view a locked public dashboard", %{conn: conn} do
      site = new_site(locked: true, public: true)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      resp = html_response(conn, 200)

      [{"div", attrs, _}] = find(resp, @react_container)
      assert Enum.all?(attrs, fn {k, v} -> is_binary(k) and is_binary(v) end)
    end

    test "shows CRM link to the site", %{conn: conn} do
      site = new_site()
      conn = get(conn, conn |> get("/" <> site.domain) |> redirected_to())
      assert html_response(conn, 200) =~ "/crm/sites/site/#{site.id}"
    end
  end

  defp make_user_super_admin(%{user: user}) do
    Application.put_env(:plausible, :super_admin_user_ids, [user.id])
  end

  describe "GET /:domain/export" do
    setup [:create_user, :create_site, :log_in]

    test "exports all the necessary CSV files", %{conn: conn, site: site} do
      conn = get(conn, "/" <> site.domain <> "/export")

      assert {"content-type", "application/zip; charset=utf-8"} =
               List.keyfind(conn.resp_headers, "content-type", 0)

      {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

      zip = Enum.map(zip, fn {filename, _} -> filename end)

      assert ~c"visitors.csv" in zip
      assert ~c"browsers.csv" in zip
      assert ~c"browser_versions.csv" in zip
      assert ~c"cities.csv" in zip
      assert ~c"conversions.csv" in zip
      assert ~c"countries.csv" in zip
      assert ~c"devices.csv" in zip
      assert ~c"entry_pages.csv" in zip
      assert ~c"exit_pages.csv" in zip
      assert ~c"operating_systems.csv" in zip
      assert ~c"operating_system_versions.csv" in zip
      assert ~c"pages.csv" in zip
      assert ~c"regions.csv" in zip
      assert ~c"sources.csv" in zip
      assert ~c"channels.csv" in zip
      assert ~c"utm_campaigns.csv" in zip
      assert ~c"utm_contents.csv" in zip
      assert ~c"utm_mediums.csv" in zip
      assert ~c"utm_sources.csv" in zip
      assert ~c"utm_terms.csv" in zip
    end

    test "exports scroll depth metric in pages.csv", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 12, pathname: "/blog", timestamp: t1, scroll_depth: 20),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: t1),
        build(:pageleave, user_id: 12, pathname: "/another", timestamp: t2, scroll_depth: 24),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 34, pathname: "/blog", timestamp: t1, scroll_depth: 17),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: t1),
        build(:pageleave, user_id: 34, pathname: "/another", timestamp: t2, scroll_depth: 26),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t2),
        build(:pageleave, user_id: 34, pathname: "/blog", timestamp: t3, scroll_depth: 60),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 56, pathname: "/blog", timestamp: t1, scroll_depth: 100)
      ])

      pages =
        conn
        |> get("/#{site.domain}/export?date=2020-01-01")
        |> response(200)
        |> unzip_and_parse_csv(~c"pages.csv")

      assert pages == [
               ["name", "visitors", "pageviews", "bounce_rate", "time_on_page", "scroll_depth"],
               ["/blog", "3", "4", "33", "60.0", "60"],
               ["/another", "2", "2", "0", "60.0", "25"],
               [""]
             ]
    end

    test "exports only internally used props in custom_props.csv for a growth plan", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      site = Repo.preload(site, :owner)
      subscribe_to_growth_plan(site.owner)

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["a"]),
        build(:event, name: "File Download", "meta.key": ["url"], "meta.value": ["b"])
      ])

      result =
        conn
        |> get("/" <> site.domain <> "/export?period=day")
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["url", "(none)", "1", "1", "50.0"],
               ["url", "b", "1", "1", "50.0"],
               [""]
             ]
    end

    test "does not include custom_props.csv for a growth plan if no internal props used", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      site = Repo.preload(site, :owner)
      subscribe_to_growth_plan(site.owner)

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["a"])
      ])

      {:ok, zip} =
        conn
        |> get("/#{site.domain}/export?period=day")
        |> response(200)
        |> :zip.unzip([:memory])

      files = Map.new(zip)

      refute Map.has_key?(files, ~c"custom_props.csv")
    end

    test "exports data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?date=2021-10-20")
      assert_zip(conn, "30d")
    end

    test "fails to export with interval=undefined, looking at you, spiders", %{
      conn: conn,
      site: site
    } do
      assert conn
             |> get("/" <> site.domain <> "/export?date=2021-10-20&interval=undefined")
             |> response(400)
    end

    test "exports allowed event props for a trial account", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:event, "meta.key": ["author"], "meta.value": ["marko"], name: "Newsletter Signup"),
        build(:pageview, user_id: 999, "meta.key": ["logged_in"], "meta.value": ["true"]),
        build(:pageview, user_id: 999, "meta.key": ["logged_in"], "meta.value": ["true"]),
        build(:pageview, "meta.key": ["disallowed"], "meta.value": ["whatever"]),
        build(:pageview)
      ])

      result =
        conn
        |> get("/" <> site.domain <> "/export?period=day")
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["author", "(none)", "3", "4", "50.0"],
               ["author", "uku", "2", "2", "33.3"],
               ["author", "marko", "1", "1", "16.7"],
               ["logged_in", "(none)", "5", "5", "83.3"],
               ["logged_in", "true", "1", "2", "16.7"],
               [""]
             ]
    end

    test "exports data grouped by interval", %{conn: conn, site: site} do
      populate_exported_stats(site)

      visitors =
        conn
        |> get("/" <> site.domain <> "/export?date=2021-10-20&period=30d&interval=week")
        |> response(200)
        |> unzip_and_parse_csv(~c"visitors.csv")

      assert visitors == [
               [
                 "date",
                 "visitors",
                 "pageviews",
                 "visits",
                 "views_per_visit",
                 "bounce_rate",
                 "visit_duration"
               ],
               ["2021-09-20", "1", "1", "1", "1.0", "100", "0"],
               ["2021-09-27", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-04", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-11", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-18", "3", "4", "3", "1.33", "33", "40"],
               [""]
             ]
    end

    test "exports operating system versions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview,
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:pageview,
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:pageview, operating_system: "Mac", operating_system_version: "13")
      ])

      os_versions =
        conn
        |> get("/#{site.domain}/export")
        |> response(200)
        |> unzip_and_parse_csv(~c"operating_system_versions.csv")

      assert os_versions == [
               ["name", "version", "visitors"],
               ["Mac", "14", "3"],
               ["Ubuntu", "20.04", "2"],
               ["Mac", "13", "1"],
               [""]
             ]
    end

    test "exports imported data when requested", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      insert(:goal, site: site, event_name: "Outbound Link: Click")

      populate_stats(site, site_import.id, [
        build(:imported_visitors, visitors: 9),
        build(:imported_browsers, browser: "Chrome", pageviews: 1),
        build(:imported_devices, device: "Desktop", pageviews: 1),
        build(:imported_entry_pages, entry_page: "/test", pageviews: 1),
        build(:imported_exit_pages, exit_page: "/test", pageviews: 1),
        build(:imported_locations,
          country: "PL",
          region: "PL-22",
          city: 3_099_434,
          pageviews: 1
        ),
        build(:imported_operating_systems, operating_system: "Mac", pageviews: 1),
        build(:imported_pages, page: "/test", pageviews: 1),
        build(:imported_sources,
          source: "Google",
          channel: "Paid Search",
          utm_medium: "search",
          utm_campaign: "ads",
          utm_source: "google",
          utm_content: "content",
          utm_term: "term",
          pageviews: 1
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://example.com",
          visitors: 5,
          events: 10
        )
      ])

      conn = get(conn, "/#{site.domain}/export?with_imported=true")

      assert response = response(conn, 200)
      {:ok, zip} = :zip.unzip(response, [:memory])

      filenames = zip |> Enum.map(fn {filename, _} -> to_string(filename) end)

      # NOTE: currently, custom_props.csv is not populated from imported data
      expected_filenames = [
        "visitors.csv",
        "sources.csv",
        "channels.csv",
        "utm_mediums.csv",
        "utm_sources.csv",
        "utm_campaigns.csv",
        "utm_contents.csv",
        "utm_terms.csv",
        "pages.csv",
        "entry_pages.csv",
        "exit_pages.csv",
        "countries.csv",
        "regions.csv",
        "cities.csv",
        "browsers.csv",
        "browser_versions.csv",
        "operating_systems.csv",
        "operating_system_versions.csv",
        "devices.csv",
        "conversions.csv",
        "referrers.csv"
      ]

      Enum.each(expected_filenames, fn expected ->
        assert expected in filenames
      end)

      Enum.each(zip, fn
        {~c"visitors.csv", data} ->
          csv = parse_csv(data)

          assert List.first(csv) == [
                   "date",
                   "visitors",
                   "pageviews",
                   "visits",
                   "views_per_visit",
                   "bounce_rate",
                   "visit_duration"
                 ]

          assert Enum.at(csv, -2) ==
                   [Date.to_iso8601(Date.utc_today()), "9", "1", "1", "1.0", "0.0", "10.0"]

        {~c"sources.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Google", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"channels.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Paid Search", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_mediums.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["search", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_sources.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["google", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_campaigns.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["ads", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_contents.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["content", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_terms.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["term", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"pages.csv", data} ->
          assert parse_csv(data) == [
                   [
                     "name",
                     "visitors",
                     "pageviews",
                     "bounce_rate",
                     "time_on_page",
                     "scroll_depth"
                   ],
                   ["/test", "1", "1", "0.0", "10.0", ""],
                   [""]
                 ]

        {~c"entry_pages.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "unique_entrances", "total_entrances", "visit_duration"],
                   ["/test", "1", "1", "10.0"],
                   [""]
                 ]

        {~c"exit_pages.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "unique_exits", "total_exits", "exit_rate"],
                   ["/test", "1", "1", "100.0"],
                   [""]
                 ]

        {~c"countries.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Poland", "1"], [""]]

        {~c"regions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors"],
                   ["Pomerania", "1"],
                   [""]
                 ]

        {~c"cities.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Gdańsk", "1"], [""]]

        {~c"browsers.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors"],
                   ["Chrome", "1"],
                   [""]
                 ]

        {~c"browser_versions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "version", "visitors"],
                   ["Chrome", "(not set)", "1"],
                   [""]
                 ]

        {~c"operating_systems.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Mac", "1"], [""]]

        {~c"operating_system_versions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "version", "visitors"],
                   ["Mac", "(not set)", "1"],
                   [""]
                 ]

        {~c"devices.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Desktop", "1"], [""]]

        {~c"conversions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "unique_conversions", "total_conversions"],
                   ["Outbound Link: Click", "5", "10"],
                   [""]
                 ]

        {~c"referrers.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Direct / None", "1", "0.0", "10.0"],
                   [""]
                 ]
      end)
    end
  end

  defp parse_csv(file_content) when is_binary(file_content) do
    file_content
    |> String.split("\r\n")
    |> Enum.map(&String.split(&1, ","))
  end

  describe "GET /:domain/export - via shared link" do
    test "exports data in zipped csvs", %{conn: conn} do
      site = new_site(domain: "new-site.com")
      link = insert(:shared_link, site: site)

      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?auth=#{link.slug}&date=2021-10-20")
      assert_zip(conn, "30d")
    end
  end

  describe "GET /:domain/export - for past 6 months" do
    setup [:create_user, :create_site, :log_in]

    test "exports 6 months of data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?period=6mo&date=2021-10-20")
      assert_zip(conn, "6m")
    end
  end

  describe "GET /:domain/export - with path filter" do
    setup [:create_user, :create_site, :log_in]

    test "exports filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      filters = Jason.encode!([[:is, "event:page", ["/some-other-page"]]])
      conn = get(conn, "/#{site.domain}/export?date=2021-10-20&filters=#{filters}")
      assert_zip(conn, "30d-filter-path")
    end

    test "exports scroll depth in visitors.csv", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageleave,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-05 00:01:00],
          scroll_depth: 40
        ),
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2020-01-05 10:00:00]),
        build(:pageleave,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-05 10:01:00],
          scroll_depth: 17
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: ~N[2020-01-07 00:00:00]),
        build(:pageleave,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-07 00:01:00],
          scroll_depth: 90
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/blog"]]])

      pages =
        conn
        |> get("/#{site.domain}/export?date=2020-01-07&period=7d&filters=#{filters}")
        |> response(200)
        |> unzip_and_parse_csv(~c"visitors.csv")

      assert pages == [
               [
                 "date",
                 "visitors",
                 "pageviews",
                 "visits",
                 "views_per_visit",
                 "bounce_rate",
                 "visit_duration",
                 "scroll_depth"
               ],
               ["2020-01-01", "0", "0", "0", "0.0", "0.0", "", ""],
               ["2020-01-02", "0", "0", "0", "0.0", "0.0", "", ""],
               ["2020-01-03", "0", "0", "0", "0.0", "0.0", "", ""],
               ["2020-01-04", "0", "0", "0", "0.0", "0.0", "", ""],
               ["2020-01-05", "1", "2", "2", "1.0", "100", "0", "40"],
               ["2020-01-06", "0", "0", "0", "0.0", "0.0", "", ""],
               ["2020-01-07", "1", "1", "1", "1.0", "100", "0", "90"],
               [""]
             ]
    end
  end

  describe "GET /:domain/export - with a custom prop filter" do
    setup [:create_user, :create_site, :log_in]

    test "custom-props.csv only returns the prop and its value in filter", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:pageview, "meta.key": ["author"], "meta.value": ["marko"]),
        build(:pageview, "meta.key": ["logged_in"], "meta.value": ["true"])
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["marko"]]])

      result =
        conn
        |> get("/" <> site.domain <> "/export?period=day&filters=#{filters}")
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["author", "marko", "1", "1", "100.0"],
               [""]
             ]
    end
  end

  defp unzip_and_parse_csv(archive, filename) do
    {:ok, zip} = :zip.unzip(archive, [:memory])
    {_filename, data} = Enum.find(zip, &(elem(&1, 0) == filename))
    parse_csv(data)
  end

  defp assert_zip(conn, folder) do
    assert conn.status == 200

    assert {"content-type", "application/zip; charset=utf-8"} =
             List.keyfind(conn.resp_headers, "content-type", 0)

    {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

    folder = Path.expand(folder, "test/plausible_web/controllers/CSVs")

    Enum.map(zip, &assert_csv_by_fixture(&1, folder))
  end

  defp assert_csv_by_fixture({file, downloaded}, folder) do
    file = Path.expand(file, folder)

    {:ok, content} = File.read(file)
    msg = "CSV file comparison failed (#{file})"
    assert downloaded == content, message: msg, left: downloaded, right: content
  end

  defp populate_exported_stats(site) do
    populate_stats(site, [
      build(:pageview,
        user_id: 123,
        pathname: "/",
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], minutes: -1) |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:pageview,
        user_id: 123,
        pathname: "/some-other-page",
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], minutes: -2) |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:pageview,
        pathname: "/",
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], days: -1) |> NaiveDateTime.truncate(:second),
        utm_medium: "search",
        utm_campaign: "ads",
        utm_source: "google",
        utm_content: "content",
        utm_term: "term",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:pageview,
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], months: -1) |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:pageview,
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], months: -5) |> NaiveDateTime.truncate(:second),
        utm_campaign: "ads",
        country_code: "EE",
        referrer_source: "Google",
        click_id_param: "gclid",
        browser: "FirefoxNoVersion",
        operating_system: "MacNoVersion"
      ),
      build(:pageview,
        user_id: 456,
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], days: -1, minutes: -1)
          |> NaiveDateTime.truncate(:second),
        pathname: "/signup",
        "meta.key": ["variant"],
        "meta.value": ["A"]
      ),
      build(:event,
        user_id: 456,
        timestamp:
          Timex.shift(~N[2021-10-20 12:00:00], days: -1) |> NaiveDateTime.truncate(:second),
        name: "Signup",
        "meta.key": ["variant"],
        "meta.value": ["A"]
      )
    ])

    insert(:goal, %{site: site, event_name: "Signup"})
  end

  describe "GET /:domain/export - with goal filter" do
    setup [:create_user, :create_site, :log_in]

    test "exports goal-filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])
      conn = get(conn, "/#{site.domain}/export?date=2021-10-20&filters=#{filters}")
      assert_zip(conn, "30d-filter-goal")
    end

    test "custom-props.csv only returns the prop names for the goal in filter", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["uku"]),
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["marko"]),
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["marko"]),
        build(:pageview, "meta.key": ["logged_in"], "meta.value": ["true"])
      ])

      insert(:goal, site: site, event_name: "Newsletter Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Newsletter Signup"]]])

      result =
        conn
        |> get("/" <> site.domain <> "/export?period=day&filters=#{filters}")
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "conversion_rate"],
               ["author", "marko", "2", "2", "50.0"],
               ["author", "uku", "1", "1", "25.0"],
               [""]
             ]
    end

    test "exports conversions and conversion rate for operating system versions", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:event,
          name: "Signup",
          operating_system: "Mac",
          operating_system_version: "14"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Mac",
          operating_system_version: "14"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Mac",
          operating_system_version: "14"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Lubuntu",
          operating_system_version: "20.04"
        )
      ])

      insert(:goal, site: site, event_name: "Signup")

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      os_versions =
        conn
        |> get("/#{site.domain}/export?filters=#{filters}")
        |> response(200)
        |> unzip_and_parse_csv(~c"operating_system_versions.csv")

      assert os_versions == [
               ["name", "version", "conversions", "conversion_rate"],
               ["Mac", "14", "3", "75.0"],
               ["Ubuntu", "20.04", "2", "100.0"],
               ["Lubuntu", "20.04", "1", "100.0"],
               [""]
             ]
    end
  end

  describe "GET /share/:domain?auth=:auth" do
    test "prompts a password for a password-protected link", %{conn: conn} do
      site = insert(:site)

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = get(conn, "/share/#{site.domain}?auth=#{link.slug}")
      assert response(conn, 200) =~ "Enter password"
    end

    test "logs anonymous user in straight away if the link is not password-protected", %{
      conn: conn
    } do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      assert html_response(conn, 200) =~ "stats-react-container"
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
      assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []

      [{"div", attrs, _}] = find(resp, @react_container)
      assert Enum.all?(attrs, fn {k, v} -> is_binary(k) and is_binary(v) end)
    end

    test "shows locked page if page is locked", %{conn: conn} do
      site = insert(:site, domain: "test-site.com", locked: true)
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")

      assert html_response(conn, 200) =~ "Dashboard locked"
      refute String.contains?(html_response(conn, 200), "Back to my sites")
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
  end

  describe "GET /share/:slug - backwards compatibility" do
    test "it redirects to new shared link format for historical links", %{conn: conn} do
      site = insert(:site, domain: "test-site.com")
      site_link = insert(:shared_link, site: site, inserted_at: ~N[2021-12-31 00:00:00])

      conn = get(conn, "/share/#{site_link.slug}")
      assert redirected_to(conn, 302) == "/share/#{site.domain}?auth=#{site_link.slug}"
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
      assert redirected_to(conn, 302) == "/share/#{site.domain}?auth=#{link.slug}"

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
      site = insert(:site, domain: "test-site.com")
      site2 = insert(:site, domain: "test-site2.com")

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      link2 =
        insert(:shared_link,
          site: site2,
          password_hash: Plausible.Auth.Password.hash("password1")
        )

      conn = post(conn, "/share/#{link.slug}/authenticate", %{password: "password"})
      assert redirected_to(conn, 302) == "/share/#{site.domain}?auth=#{link.slug}"

      conn = get(conn, "/share/#{site2.domain}?auth=#{link2.slug}")
      assert html_response(conn, 200) =~ "Enter password"
    end
  end
end
