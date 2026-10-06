defmodule PlausibleWeb.Api.StatsController.CurrentVisitorsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/current-visitors" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique users in the last 5 minutes", %{conn: conn, site: site} do
      now = DateTime.utc_now()

      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: now |> DateTime.shift(minute: -3)),
        build(:pageview, user_id: 456, timestamp: now |> DateTime.shift(minute: -3)),
        build(:pageview, user_id: 123, timestamp: now |> DateTime.shift(minute: -1)),
        build(:pageview, user_id: 789, timestamp: now |> DateTime.shift(minute: -7)),
        build(:engagement, user_id: 789, timestamp: now |> DateTime.shift(minute: -3))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/current-visitors")

      assert json_response(conn, 200) == 2
    end
  end
end
