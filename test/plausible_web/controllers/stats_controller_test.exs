defmodule PlausibleWeb.StatsControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  describe "as an anonymous visitor" do
    test "public site - shows site stats", %{conn: conn} do
      insert(:site, domain: "public-site.io", public: true)
      insert(:pageview, hostname: "public-site.io")

      conn = get(conn, "/public-site.io")
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "can not view stats of a private website", %{conn: conn} do
      insert(:pageview, hostname: "some-other-site.com")

      conn = get(conn, "/some-other-site.com")
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end

  describe "as a logged in user" do
    setup [:create_user, :log_in, :create_site]

    test "can view stats of a website I've created", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain)

      conn = get(conn, "/" <> site.domain)
      assert html_response(conn, 200) =~ "stats-react-container"
    end

    test "can not view stats of someone else's website", %{conn: conn} do
      insert(:pageview, hostname: "some-other-site.com")

      conn = get(conn, "/some-other-site.com")
      assert html_response(conn, 404) =~ "There&#39;s nothing here"
    end
  end
end
