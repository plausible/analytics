defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_site]

    test "returns custom event conversions", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, event_name: "Register"})
      insert(:goal, %{domain: site.domain, event_name: "Newsletter signup"})
      insert(:event, name: "Register", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Register", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Newsletter signup", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Irrelevant", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Register",  "count" => 2},
        %{"name" => "Newsletter signup", "count" => 1},
      ]
    end

    test "returns pageview conversions", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/success"})
      insert(:goal, %{domain: site.domain, page_path: "/register"})

      insert(:event, name: "pageview", pathname: "/success", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "pageview", pathname: "/success", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "pageview", pathname: "/register", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "pageview", pathname: "/irrelevant", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Visit /success",  "count" => 2},
        %{"name" => "Visit /register", "count" => 1},
      ]
    end

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/success"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      insert(:event, name: "Signup", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "pageview", pathname: "/success", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "pageview", pathname: "/success", hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Visit /success",  "count" => 2},
        %{"name" => "Signup", "count" => 1},
      ]
    end
  end
end
