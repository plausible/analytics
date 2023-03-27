defmodule PlausibleWeb.Api.StatsController.CurrentVisitorsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/current-visitors" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique users in the last 5 minutes", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123),
        build(:pageview, user_id: 456)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/current-visitors")

      assert json_response(conn, 200) == 2
    end
  end
end
