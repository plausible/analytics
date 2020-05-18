defmodule PlausibleWeb.Api.StatsController.CurrentVisitorsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/current-visitors" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique users in the last 5 minutes", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/current-visitors")

      assert json_response(conn, 200) == 2
    end
  end
end
