defmodule PlausibleWeb.StatsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /:website - anonymous user" do
    test "public site - shows site stats", %{conn: conn} do
      insert(:site, domain: "public-site.io", public: true)

      conn = get(conn, "/public-site.io")
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "public site - shows waiting for first pageview", %{conn: conn} do
      insert(:site, domain: "some-other-public-site.io", public: true)

      conn = get(conn, "/some-other-public-site.io")
      assert html_response(conn, 200) =~ "Need to see the snippet again?"
    end

    test "can not view stats of a private website", %{conn: conn} do
      conn = get(conn, "/test-site.com")
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end

  describe "GET /:website - as a logged in user" do
    setup [:create_user, :log_in, :create_site]

    test "can view stats of a website I've created", %{conn: conn, site: site} do
      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "shows locked page if page is locked", %{conn: conn, user: user} do
      locked_site = insert(:site, locked: true, members: [user])
      conn = get(conn, "/" <> locked_site.domain)
      assert html_response(conn, 200) =~ "Site locked"
    end

    test "can not view stats of someone else's website", %{conn: conn} do
      site = insert(:site)
      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end

  describe "GET /:website - as a super admin" do
    setup [:create_user, :make_user_super_admin, :log_in]

    test "can view a private dashboard with stats", %{conn: conn} do
      site = insert(:site)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "can view a private dashboard without stats", %{conn: conn} do
      site = insert(:site)

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "Need to see the snippet again?"
    end

    test "can view a private locked dashboard with stats", %{conn: conn} do
      user = insert(:user)
      site = insert(:site, locked: true, members: [user])
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
      assert html_response(conn, 200) =~ "This dashboard is actually locked"
    end

    test "can view a private locked dashboard without stats", %{conn: conn} do
      user = insert(:user)
      site = insert(:site, locked: true, members: [user])

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "Need to see the snippet again?"
      assert html_response(conn, 200) =~ "This dashboard is actually locked"
    end

    test "can view a locked public dashboard", %{conn: conn} do
      site = insert(:site, locked: true, public: true)
      populate_stats(site, [build(:pageview)])

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
    end
  end

  defp make_user_super_admin(%{user: user}) do
    Application.put_env(:plausible, :super_admin_user_ids, [user.id])
  end

  describe "GET /:website/export" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?date=2021-10-20")
      assert_zip(conn, "30d")
    end

    test "exports data grouped by interval", %{conn: conn, site: site} do
      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?date=2021-10-20&period=30d&interval=week")

      assert response = response(conn, 200)
      {:ok, zip} = :zip.unzip(response, [:memory])

      {_filename, visitors} =
        Enum.find(zip, fn {filename, _data} -> filename == 'visitors.csv' end)

      parsed_csv =
        visitors
        |> String.split("\r\n")
        |> Enum.map(&String.split(&1, ","))

      assert parsed_csv == [
               ["date", "visitors", "pageviews", "bounce_rate", "visit_duration"],
               ["2021-09-20", "1", "1", "100", "0"],
               ["2021-09-27", "0", "0", "", ""],
               ["2021-10-04", "0", "0", "", ""],
               ["2021-10-11", "0", "0", "", ""],
               ["2021-10-18", "3", "3", "67", "20"],
               [""]
             ]
    end
  end

  describe "GET /:website/export - via shared link" do
    test "exports data in zipped csvs", %{conn: conn} do
      site = insert(:site, domain: "new-site.com")
      link = insert(:shared_link, site: site)

      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?auth=#{link.slug}&date=2021-10-20")
      assert_zip(conn, "30d")
    end
  end

  describe "GET /:website/export - for past 6 months" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports 6 months of data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      conn = get(conn, "/" <> site.domain <> "/export?period=6mo&date=2021-10-20")
      assert_zip(conn, "6m")
    end
  end

  describe "GET /:website/export - with path filter" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      filters = Jason.encode!(%{page: "/some-other-page"})
      conn = get(conn, "/#{site.domain}/export?date=2021-10-20&filters=#{filters}")
      assert_zip(conn, "30d-filter-path")
    end
  end

  defp assert_zip(conn, folder) do
    assert conn.status == 200

    assert {"content-type", "application/zip; charset=utf-8"} =
             List.keyfind(conn.resp_headers, "content-type", 0)

    {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

    folder = Path.expand(folder, "test/plausible_web/controllers/CSVs")

    Enum.map(zip, &assert_csv(&1, folder))
  end

  defp assert_csv({file, downloaded}, folder) do
    file = Path.expand(file, folder)

    {:ok, content} = File.read(file)
    msg = "CSV file comparison failed (#{file})"
    assert downloaded == content, message: msg, left: downloaded, right: content
  end

  defp populate_exported_stats(site) do
    populate_stats(site, [
      build(:pageview,
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        pathname: "/",
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], minutes: -1),
        referrer_source: "Google",
        user_id: 123
      ),
      build(:pageview,
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        pathname: "/some-other-page",
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], minutes: -2),
        referrer_source: "Google",
        user_id: 123
      ),
      build(:pageview,
        pathname: "/",
        utm_medium: "search",
        utm_campaign: "ads",
        utm_source: "google",
        utm_content: "content",
        utm_term: "term",
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], days: -1),
        browser: "ABrowserName"
      ),
      build(:pageview,
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], months: -1),
        country_code: "EE",
        browser: "ABrowserName"
      ),
      build(:pageview,
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], months: -5),
        utm_campaign: "ads",
        country_code: "EE",
        referrer_source: "Google",
        browser: "ABrowserName"
      ),
      build(:event,
        timestamp: Timex.shift(~N[2021-10-20 12:00:00], days: -1),
        name: "Signup",
        "meta.key": ["variant"],
        "meta.value": ["A"]
      )
    ])

    insert(:goal, %{domain: site.domain, event_name: "Signup"})
  end

  describe "GET /:website/export - with goal filter" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports goal-filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)
      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/#{site.domain}/export?date=2021-10-20&filters=#{filters}")
      assert_zip(conn, "30d-filter-goal")
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
      site = insert(:site, domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "returns page with X-Frame-Options disabled so it can be embedded in an iframe", %{
      conn: conn
    } do
      site = insert(:site, domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")
      assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []
    end

    test "shows locked page if page is locked", %{conn: conn} do
      site = insert(:site, domain: "test-site.com", locked: true)
      link = insert(:shared_link, site: site)

      conn = get(conn, "/share/test-site.com/?auth=#{link.slug}")

      assert html_response(conn, 200) =~ "Site locked"
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
      site = insert(:site, domain: "test-site.com")

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
        insert(:shared_link, site: site2, password_hash: Plausible.Auth.Password.hash("password1"))

      conn = post(conn, "/share/#{link.slug}/authenticate", %{password: "password"})
      assert redirected_to(conn, 302) == "/share/#{site.domain}?auth=#{link.slug}"

      conn = get(conn, "/share/#{site2.domain}?auth=#{link2.slug}")
      assert html_response(conn, 200) =~ "Enter password"
    end
  end
end
