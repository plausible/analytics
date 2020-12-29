defmodule PlausibleWeb.Api.InternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  describe "GET /api/:domain/status" do
    setup [:create_user, :log_in]

    test "is WAITING when site has no pageviews", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "WAITING"
    end

    test "is READY when site has at least 1 pageview", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      Plausible.TestUtils.create_pageviews([%{domain: site.domain}])

      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "READY"
    end
  end

  describe "GET /api/status" do
    setup [:create_user, :log_in]

    test "returns a list of site domains for the current user", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      site2 = insert(:site, members: [user])
      conn = get(conn, "/api/sites")

      assert json_response(conn, 200) == [site.domain, site2.domain]
    end
  end
end
