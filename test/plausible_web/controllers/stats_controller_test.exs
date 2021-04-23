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

    test "can not view stats of someone else's website", %{conn: conn} do
      conn = get(conn, "/some-other-site.com")
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end

  describe "GET /:website/visitors.csv" do
    setup [:create_user, :log_in, :create_site]

    test "exports graph as csv", %{conn: conn, site: site} do
      today = Timex.today() |> Timex.format!("{ISOdate}")

      conn = get(conn, "/" <> site.domain <> "/visitors.csv")
      assert response(conn, 200) =~ "visitors,pageviews,bounce_rate,visit_duration"
      assert response(conn, 200) =~ "#{today},3,3,0,0"
    end
  end

  describe "GET /:website/visitors.csv - via shared link" do
    test "exports graph as csv", %{conn: conn} do
      site = insert(:site, domain: "test-site.com")
      link = insert(:shared_link, site: site)

      today = Timex.today() |> Timex.format!("{ISOdate}")

      conn = get(conn, "/" <> site.domain <> "/visitors.csv?auth=#{link.slug}")
      assert response(conn, 200) =~ "visitors,pageviews,bounce_rate,visit_duration"
      assert response(conn, 200) =~ "#{today},3,3,0,0"
    end
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
