defmodule PlausibleWeb.Api.StatsController.SourcesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id 123

  describe "GET /api/stats/:domain/sources" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top sources by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources")

      assert json_response(conn, 200) == [
               %{"name" => "Google", "count" => 2},
               %{"name" => "DuckDuckGo", "count" => 1}
             ]
    end

    test "calculates bounce rate and visit duration for sources", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Google",
                 "count" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               },
               %{
                 "name" => "DuckDuckGo",
                 "count" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]
    end

    test "returns top sources in realtime report", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: relative_time(minutes: -3)
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: relative_time(minutes: -2)
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: relative_time(minutes: -1)
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources?period=realtime")

      assert json_response(conn, 200) == [
               %{"name" => "Google", "count" => 2},
               %{"name" => "DuckDuckGo", "count" => 1}
             ]
    end

    test "can paginate the results", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources?limit=1&page=2")

      assert json_response(conn, 200) == [
               %{"name" => "DuckDuckGo", "count" => 1}
             ]
    end

    test "shows sources for a page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/page1", referrer_source: "Google"),
        build(:pageview, pathname: "/page2", referrer_source: "Google"),
        build(:pageview, user_id: 1, pathname: "/page2", referrer_source: "DuckDuckGo"),
        build(:pageview, user_id: 1, pathname: "/page1", referrer_source: "DuckDuckGo")
      ])

      filters = Jason.encode!(%{"page" => "/page1"})
      conn = get(conn, "/api/stats/#{site.domain}/sources?filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Google", "count" => 1}
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_mediums" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top utm_mediums by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_medium: "social",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_medium: "social",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          utm_medium: "email",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "social",
                 "count" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               },
               %{
                 "name" => "email",
                 "count" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_campaigns" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top utm_campaigns by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_campaign: "profile",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_campaign: "profile",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          utm_campaign: "august",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_campaign: "august",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "august",
                 "count" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "profile",
                 "count" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_sources" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top utm_sources by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_source: "Twitter",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_source: "Twitter",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          utm_source: "newsletter",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_source: "newsletter",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_sources?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "newsletter",
                 "count" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "Twitter",
                 "count" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/sources - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top referrers for a custom goal including conversion_rate", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Twitter",
          user_id: @user_id
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id
        ),
        build(:pageview,
          referrer_source: "Twitter"
        )
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Twitter", "count" => 1, "conversion_rate" => 50.0}
             ]
    end

    test "returns top referrers for a pageview goal including conversion_rate", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Twitter",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/register",
          user_id: @user_id
        ),
        build(:pageview,
          referrer_source: "Twitter"
        )
      ])

      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Twitter", "count" => 1, "conversion_rate" => 50.0}
             ]
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top referrers for a particular source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com"
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com"
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com/page1"
        ),
        build(:pageview,
          referrer_source: "ignored",
          referrer: "ignored"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 3,
               "referrers" => [
                 %{"name" => "10words.com", "count" => 2},
                 %{"name" => "10words.com/page1", "count" => 1}
               ]
             }
    end

    test "calculates bounce rate and visit duration for referrer urls", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          referrer_source: "ignored",
          referrer: "ignored",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&date=2021-01-01&detailed=true"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 2,
               "referrers" => [
                 %{
                   "name" => "10words.com",
                   "count" => 2,
                   "bounce_rate" => 50.0,
                   "visit_duration" => 450
                 }
               ]
             }
    end

    test "gets keywords from Google", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, user: user, site: site, property: "sc-domain:example.com")

      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day")
      {:ok, terms} = Plausible.Google.Api.Mock.fetch_stats(nil, nil, nil)

      assert json_response(conn, 200) == %{
               "total_visitors" => 2,
               "search_terms" => terms
             }
    end

    test "returns top referring urls for a custom goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com"
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com",
          user_id: @user_id
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id
        ),
        build(:event,
          name: "Signup"
        )
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 1,
               "referrers" => [
                 %{"name" => "10words.com", "count" => 1}
               ]
             }
    end

    test "returns top referring urls for a pageview goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com"
        ),
        build(:pageview,
          referrer_source: "10words",
          referrer: "10words.com",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/register",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/register"
        )
      ])

      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == %{
               "total_visitors" => 1,
               "referrers" => [
                 %{"name" => "10words.com", "count" => 1}
               ]
             }
    end
  end
end
