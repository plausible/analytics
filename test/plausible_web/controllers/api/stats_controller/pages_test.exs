defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/pages" do
    setup [:create_user, :log_in, :create_site]

    test "returns top pages sources by pageviews", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, pathname: "/", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, pathname: "/", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, pathname: "/contact", timestamp: ~N[2019-01-01 01:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "/", "count" => 2},
        %{"name" => "/contact", "count" => 1},
      ]
    end
  end
end
