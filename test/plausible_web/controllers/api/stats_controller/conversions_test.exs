defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_site]

    test "returns custom event conversions", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, event_name: "Register"})
      insert(:goal, %{domain: site.domain, event_name: "Newsletter signup"})
      create_events([
        %{name: "Register", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "Register", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "Newsletter signup", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "Irrelevant", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]}
      ])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Register",  "count" => 2},
        %{"name" => "Newsletter signup", "count" => 1},
      ]
    end

    test "returns pageview conversions", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/success"})
      insert(:goal, %{domain: site.domain, page_path: "/register"})

      create_pageviews([
        %{pathname: "/success", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{pathname: "/success", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{pathname: "/register", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{pathname: "/irrelevant", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]}
      ])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Visit /success",  "count" => 2},
        %{"name" => "Visit /register", "count" => 1},
      ]
    end

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/success"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      create_events([
        %{name: "Signup", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "pageview", pathname: "/success", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "pageview", pathname: "/success", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]}
      ])

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Visit /success",  "count" => 2},
        %{"name" => "Signup", "count" => 1},
      ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns only the conversion tha is filtered for", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/success"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      create_events([
        %{name: "Signup", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]},
        %{name: "pageview", pathname: "/success", domain: site.domain, timestamp: ~N[2019-01-01 01:00:00]}
      ])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Signup", "count" => 1},
      ]
    end
  end
end
