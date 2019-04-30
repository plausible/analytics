defmodule PlausibleWeb.Api.InternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  describe "GET /:domain/status" do
    setup [:create_user, :log_in, :create_site]

    test "is WAITING when site has no pageviews", %{conn: conn, site: site} do
      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "WAITING"
    end

    test "is READY when site has at least 1 pageview", %{conn: conn, site: site} do
      Repo.insert!(%Plausible.Pageview{
        hostname: site.domain,
        pathname: "/",
        new_visitor: true,
        session_id: "123",
        user_id: "321"
      })

      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "READY"
    end
  end
end
