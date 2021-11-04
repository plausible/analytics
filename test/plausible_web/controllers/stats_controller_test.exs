defmodule PlausibleWeb.StatsControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

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
      conn = get(conn, "/some-other-site.com")
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end

  describe "GET /:website/export" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports data in zipped csvs", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          timestamp: Timex.shift(~N[2021-10-20 12:00:00], minutes: -1),
          referrer_source: "Google"
        ),
        build(:pageview,
          utm_campaign: "ads",
          timestamp: Timex.shift(~N[2021-10-20 12:00:00], days: -1)
        )
      ])

      conn = get(conn, "/" <> site.domain <> "/export?date=2021-10-20")
      assert_default_zip(conn)
    end
  end

  describe "GET /:website/export - via shared link" do
    test "exports data in zipped csvs", %{conn: conn} do
      site = insert(:site, domain: "new-site.com")
      link = insert(:shared_link, site: site)

      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          timestamp: Timex.shift(~N[2021-10-20 12:00:00], minutes: -1),
          referrer_source: "Google"
        ),
        build(:pageview,
          utm_campaign: "ads",
          timestamp: Timex.shift(~N[2021-10-20 12:00:00], days: -1)
        )
      ])

      conn = get(conn, "/" <> site.domain <> "/export?auth=#{link.slug}&date=2021-10-20")
      assert_default_zip(conn)
    end
  end

  defp assert_default_zip(conn) do
    assert conn.status == 200

    assert {"content-type", "application/zip; charset=utf-8"} =
             List.keyfind(conn.resp_headers, "content-type", 0)

    {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

    assert_csv(
      zip,
      'visitors.csv',
      "date,visitors,pageviews,bounce_rate,visit_duration\r\n2021-09-20,0,0,,\r\n2021-09-21,0,0,,\r\n2021-09-22,0,0,,\r\n2021-09-23,0,0,,\r\n2021-09-24,0,0,,\r\n2021-09-25,0,0,,\r\n2021-09-26,0,0,,\r\n2021-09-27,0,0,,\r\n2021-09-28,0,0,,\r\n2021-09-29,0,0,,\r\n2021-09-30,0,0,,\r\n2021-10-01,0,0,,\r\n2021-10-02,0,0,,\r\n2021-10-03,0,0,,\r\n2021-10-04,0,0,,\r\n2021-10-05,0,0,,\r\n2021-10-06,0,0,,\r\n2021-10-07,0,0,,\r\n2021-10-08,0,0,,\r\n2021-10-09,0,0,,\r\n2021-10-10,0,0,,\r\n2021-10-11,0,0,,\r\n2021-10-12,0,0,,\r\n2021-10-13,0,0,,\r\n2021-10-14,0,0,,\r\n2021-10-15,0,0,,\r\n2021-10-16,0,0,,\r\n2021-10-17,0,0,,\r\n2021-10-18,0,0,,\r\n2021-10-19,1,1,100,0\r\n2021-10-20,1,1,100,0\r\n"
    )

    assert_csv(
      zip,
      'sources.csv',
      "name,visitors,bounce_rate,visit_duration\r\nGoogle,1,100,0\r\n"
    )

    assert_csv(zip, 'utm_mediums.csv', "name,visitors,bounce_rate,visit_duration\r\n")
    assert_csv(zip, 'utm_sources.csv', "name,visitors,bounce_rate,visit_duration\r\n")

    assert_csv(
      zip,
      'utm_campaigns.csv',
      "name,visitors,bounce_rate,visit_duration\r\nads,1,100,0\r\n"
    )

    assert_csv(zip, 'pages.csv', "name,visitors,bounce_rate,time_on_page\r\n/,2,100,\r\n")

    assert_csv(
      zip,
      'entry_pages.csv',
      "name,unique_entrances,total_entrances,visit_duration\r\n/,2,2,0\r\n"
    )

    assert_csv(
      zip,
      'exit_pages.csv',
      "name,unique_exits,total_exits,exit_rate\r\n/,2,2,100.0\r\n"
    )

    assert_csv(zip, 'countries.csv', "name,visitors\r\nEstonia,1\r\n")
    assert_csv(zip, 'browsers.csv', "name,visitors\r\n,2\r\n")
    assert_csv(zip, 'operating_systems.csv', "name,visitors\r\n,2\r\n")
    assert_csv(zip, 'devices.csv', "name,visitors\r\n,2\r\n")
    assert_csv(zip, 'conversions.csv', "name,unique_conversions,total_conversions\r\n")
  end

  describe "GET /:website/export - for past 6 months" do
    setup [:create_user, :create_new_site, :log_in]

    test "exports 6 months of data in zipped csvs", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: Timex.shift(~N[2021-10-20 12:00:00], minutes: -1)
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
        )
      ])

      conn = get(conn, "/" <> site.domain <> "/export?period=6mo&date=2021-10-20")
      assert conn.status == 200

      assert {"content-type", "application/zip; charset=utf-8"} =
               List.keyfind(conn.resp_headers, "content-type", 0)

      {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

      assert_csv(
        zip,
        'visitors.csv',
        "date,visitors,pageviews,bounce_rate,visit_duration\r\n2021-05-01,1,1,100,0\r\n2021-06-01,0,0,,\r\n2021-07-01,0,0,,\r\n2021-08-01,0,0,,\r\n2021-09-01,1,1,100,0\r\n2021-10-01,1,1,100,0\r\n"
      )

      assert_csv(
        zip,
        'sources.csv',
        "name,visitors,bounce_rate,visit_duration\r\nGoogle,1,100,0\r\n"
      )

      assert_csv(zip, 'utm_mediums.csv', "name,visitors,bounce_rate,visit_duration\r\n")
      assert_csv(zip, 'utm_sources.csv', "name,visitors,bounce_rate,visit_duration\r\n")

      assert_csv(
        zip,
        'utm_campaigns.csv',
        "name,visitors,bounce_rate,visit_duration\r\nads,1,100,0\r\n"
      )

      assert_csv(zip, 'pages.csv', "name,visitors,bounce_rate,time_on_page\r\n/,3,100,\r\n")

      assert_csv(
        zip,
        'entry_pages.csv',
        "name,unique_entrances,total_entrances,visit_duration\r\n/,3,3,0\r\n"
      )

      assert_csv(
        zip,
        'exit_pages.csv',
        "name,unique_exits,total_exits,exit_rate\r\n/,3,3,100.0\r\n"
      )

      assert_csv(zip, 'countries.csv', "name,visitors\r\nEstonia,2\r\n")
      assert_csv(zip, 'browsers.csv', "name,visitors\r\nABrowserName,2\r\n,1\r\n")
      assert_csv(zip, 'operating_systems.csv', "name,visitors\r\n,3\r\n")
      assert_csv(zip, 'devices.csv', "name,visitors\r\n,3\r\n")
      assert_csv(zip, 'conversions.csv', "name,unique_conversions,total_conversions\r\n")
    end
  end

  defp assert_csv(zip, fileName, string) do
    {_, contents} = List.keyfind(zip, fileName, 0)
    assert to_string(contents) == string
  end

  describe "GET /share/:slug" do
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
  end
end
