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

    test "filters referrers for a custom goal", %{conn: conn, site: site} do
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
      ]
    end

    test "filters referrers for a pageview goal", %{conn: conn, site: site} do
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/irrelevant", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Visit /register"})
      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
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

    test "gets keywords from Google", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, user: user,site: site, property: "sc-domain:example.com")
      insert(:pageview, hostname: site.domain, referrer: "google.com", referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer: "google.com", referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&date=2019-01-01")
      {:ok, terms} = Plausible.Google.Api.Mock.fetch_stats(nil, nil)

      assert json_response(conn, 200) == %{
        "total_visitors" => 2,
        "search_terms" => terms
      }
    end
  end
end
