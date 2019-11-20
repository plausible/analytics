defmodule PlausibleWeb.Api.StatsController.ReferrersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/referrers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrer sources by unique visitors", %{conn: conn, site: site} do
      pageview1 = insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", user_id: pageview1.user_id, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Bing", timestamp: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
        %{"name" => "Bing", "count" => 1},
      ]
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrers for a particular source", %{conn: conn, site: site} do
      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/somepage",
        referrer_source: "10words",
        new_visitor: true,
        timestamp: ~N[2019-01-01 01:00:00]
      })

      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/somepage",
        referrer_source: "10words",
        new_visitor: true,
        timestamp: ~N[2019-01-01 01:00:00]
      })

      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/some_other_page",
        referrer_source: "10words",
        new_visitor: true,
        timestamp: ~N[2019-01-01 01:00:00]
      })

      conn = get(conn, "/api/stats/#{site.domain}/referrers/10words?period=day&date=2019-01-01")

      assert json_response(conn, 200) == %{
        "total_visitors" => 3,
        "referrers" => [
          %{"name" => "10words.io/somepage", "count" => 2},
          %{"name" => "10words.io/some_other_page", "count" => 1},
        ]
      }
    end
  end
end
