defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top browsers by new visitors", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, browser: "Chrome", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, browser: "Chrome", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, browser: "Firefox", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Chrome",  "count" => 2, "percentage" => 67},
        %{"name" => "Firefox", "count" => 1, "percentage" => 33},
      ]
    end
  end
end
