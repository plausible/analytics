defmodule PlausibleWeb.Api.StatsController.TopReportTest do
  use PlausibleWeb.ConnCase

  @user_id 123

  describe "GET /api/stats/top-report" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns graph and top stats", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-11 04:00:00]),
        build(:pageview, timestamp: ~N[2021-01-11 05:00:00]),
        build(:pageview, timestamp: ~N[2021-01-11 18:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-report?period=day&date=2021-01-11&metric=pageviews"
        )

      assert %{"plot" => curr, "top_stats" => top_stats} = json_response(conn, 200)
      assert [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0] = curr

      assert %{
               "name" => "Unique visitors",
               "value" => 3,
               "graph_metric" => "visitors"
             } in top_stats
    end

    test "always adds comparison for top stats"
    test "compares both top stats and graph when requested"
    test "overrides metric with default when invalid metric provided"
    test "overrides interval with default when invalid interval provided"
  end
end
