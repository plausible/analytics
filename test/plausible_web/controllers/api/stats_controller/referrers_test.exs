defmodule PlausibleWeb.Api.StatsController.ReferrersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/referrers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrer sources by user ids", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "10words", "count" => 2, "url" => "10words.com"},
               %{"name" => "Bing", "count" => 1, "url" => ""}
             ]
    end

    test "calculates bounce rate and visit duration for referrers", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers?period=day&date=2019-01-01&include=bounce_rate,visit_duration"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "10words",
                 "count" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 50,
                 "url" => "10words.com"
               },
               %{
                 "name" => "Bing",
                 "count" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 100,
                 "url" => ""
               }
             ]
    end

    test "returns top referrer sources in realtime report", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/referrers?period=realtime")

      assert json_response(conn, 200) == [
               %{"name" => "10words", "count" => 2, "url" => "10words.com"},
               %{"name" => "Bing", "count" => 1, "url" => "bing.com"}
             ]
    end
  end

  describe "GET /api/stats/:domain/goal/referrers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrers for a custom goal", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/goal/referrers?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "10words", "count" => 2, "url" => "10words.com"}
             ]
    end

    test "returns top referrers for a pageview goal", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/goal/referrers?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "10words", "count" => 2, "url" => "10words.com"}
             ]
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referrers for a particular source", %{conn: conn, site: site} do
      filters = Jason.encode!(%{source: "10words"})
      conn = get(conn, "/api/stats/#{site.domain}/referrers/10words?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == %{
               "total_visitors" => 6,
               "referrers" => [
                 %{"name" => "10words.com/page1", "url" => "10words.com", "count" => 2}
               ]
             }
    end

    test "calculates bounce rate and visit duration for referrer urls", %{conn: conn, site: site} do
      filters = Jason.encode!(%{source: "10words"})
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&date=2019-01-01&filters=#{filters}&include=bounce_rate,visit_duration"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 6,
               "referrers" => [
                 %{
                   "name" => "10words.com/page1",
                   "url" => "10words.com",
                   "count" => 2,
                   "bounce_rate" => 50.0,
                   "visit_duration" => 50.0
                 }
               ]
             }
    end

    test "gets keywords from Google", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, user: user, site: site, property: "sc-domain:example.com")
      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&date=2019-02-01")
      {:ok, terms} = Plausible.Google.Api.Mock.fetch_stats(nil, nil, nil)

      assert json_response(conn, 200) == %{
               "total_visitors" => 2,
               "search_terms" => terms
             }
    end

    test "enriches twitter referrers with tweets if available", %{conn: conn, site: site} do
      insert(:tweet, link: "t.co/some-link", text: "important tweet")

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Twitter?period=day&date=2019-03-01")

      res = json_response(conn, 200)
      assert res["total_visitors"] == 3
      assert [tweet1, tweet2] = res["referrers"]

      assert %{
               "name" => "t.co/some-link",
               "count" => 2,
               "tweets" => [%{"text" => "important tweet"}]
             } = tweet1

      assert %{"name" => "t.co/nonexistent-link", "count" => 1, "tweets" => nil} = tweet2
    end
  end

  describe "GET /api/stats/:domain/goal/referrers/:referrer" do
    setup [:create_user, :log_in, :create_site]

    test "returns top referring urls for a custom goal", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/goal/referrers/10words?period=day&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 2,
               "referrers" => [
                 %{"name" => "10words.com/page1", "count" => 2}
               ]
             }
    end

    test "returns top referring urls for a pageview goal", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/goal/referrers/10words?period=day&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 2,
               "referrers" => [
                 %{"name" => "10words.com/page1", "count" => 2}
               ]
             }
    end
  end
end
