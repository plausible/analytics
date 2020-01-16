defmodule PlausibleWeb.Api.StatsController.ReferrersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/referrers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrer sources by new visitors", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: false, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Bing", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
        %{"name" => "Bing", "count" => 1},
      ]
    end

    test "calculates bounce rate for referrers", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Bing", timestamp: ~N[2019-01-01 02:00:00])

      insert(:session, hostname: site.domain, referrer_source: "Google", is_bounce: true, start: ~N[2019-01-01 02:00:00])
      insert(:session, hostname: site.domain, referrer_source: "Google", is_bounce: false, start: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01&include=bounce_rate")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2, "bounce_rate" => 50},
        %{"name" => "Bing", "count" => 1, "bounce_rate" => nil},
      ]
    end
  end

  describe "GET /api/stats/:domain/goal/referrers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrers for a custom goal", %{conn: conn, site: site} do
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/goal/referrers?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
      ]
    end

    test "returns top referrers for a pageview goal", %{conn: conn, site: site} do
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/irrelevant", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Visit /register"})
      conn = get(conn, "/api/stats/#{site.domain}/goal/referrers?period=day&date=2019-01-01&filters=#{filters}")

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

    test "calculates bounce rate for referrer urls", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, referrer_source: "10words", referrer: "10words.io/hello", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "10words", referrer: "10words.io/hello", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "10words", referrer: "10words.io/", timestamp: ~N[2019-01-01 02:00:00])

      insert(:session, hostname: site.domain, referrer_source: "10words", referrer: "10words.io/hello", is_bounce: true, start: ~N[2019-01-01 02:00:00])
      insert(:session, hostname: site.domain, referrer_source: "10words", referrer: "10words.io/hello",is_bounce: false, start: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/10words?period=day&date=2019-01-01&include=bounce_rate")

      assert json_response(conn, 200) == %{
        "total_visitors" => 3,
        "referrers" => [
          %{"name" => "10words.io/hello", "count" => 2, "bounce_rate" => 50},
          %{"name" => "10words.io/", "count" => 1, "bounce_rate" => nil},
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

    test "enriches twitter referrers with tweets if available", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, referrer: "t.co/some-link", referrer_source: "Twitter", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer: "t.co/some-link", referrer_source: "Twitter", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer: "t.co/nonexistent-link", referrer_source: "Twitter", timestamp: ~N[2019-01-01 02:00:00])

      insert(:tweet, link: "t.co/some-link", text: "important tweet")

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Twitter?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert res["total_visitors"] == 3
      assert [tweet1, tweet2] = res["referrers"]
      assert %{"name" => "t.co/some-link", "count" => 2, "tweets" => [%{"text" => "important tweet"}]} = tweet1
      assert %{"name" => "t.co/nonexistent-link", "count" => 1, "tweets" => nil} = tweet2
    end
  end

  describe "GET /api/stats/:domain/goal/referrers/:referrer" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referring urls for a custom goal", %{conn: conn, site: site} do
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Twitter", referrer: "a", timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Twitter", referrer: "a", timestamp: ~N[2019-01-01 02:00:00])
      insert(:event, name: "Signup", hostname: site.domain, referrer_source: "Twitter", referrer: "b", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/goal/referrers/Twitter?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == %{
        "total_visitors" => 3,
        "referrers" => [
          %{"name" => "a", "count" => 2},
          %{"name" => "b", "count" => 1}
        ]
      }
    end

    test "returns top referring urls for a pageview goal", %{conn: conn, site: site} do
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/register", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, pathname: "/irrelevant", hostname: site.domain, referrer_source: "Google", timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Visit /register"})
      conn = get(conn, "/api/stats/#{site.domain}/goal/referrers?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Google", "count" => 2},
      ]
    end
  end
end
