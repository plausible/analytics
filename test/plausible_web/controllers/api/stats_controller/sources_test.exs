defmodule PlausibleWeb.Api.StatsController.SourcesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id 123

  describe "GET /api/stats/:domain/sources" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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
               %{"name" => "Google", "visitors" => 2},
               %{"name" => "DuckDuckGo", "visitors" => 1}
             ]
    end

    test "returns top sources with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "Google", referrer: "google.com"),
        build(:pageview, referrer_source: "Google", referrer: "google.com"),
        build(:pageview, referrer_source: "DuckDuckGo", referrer: "duckduckgo.com")
      ])

      populate_stats(site, [
        build(:imported_sources,
          source: "Google",
          visitors: 2
        ),
        build(:imported_sources,
          source: "DuckDuckGo",
          visitors: 1
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources")

      assert json_response(conn, 200) == [
               %{"name" => "Google", "visitors" => 2},
               %{"name" => "DuckDuckGo", "visitors" => 1}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/sources?with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "Google", "visitors" => 4},
               %{"name" => "DuckDuckGo", "visitors" => 2}
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
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]
    end

    test "calculates bounce rate and visit duration for sources with imported data", %{
      conn: conn,
      site: site
    } do
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

      populate_stats(site, [
        build(:imported_sources,
          source: "Google",
          date: ~D[2021-01-01],
          visitors: 2,
          visits: 3,
          bounces: 1,
          visit_duration: 900
        ),
        build(:imported_sources,
          source: "DuckDuckGo",
          date: ~D[2021-01-01],
          visitors: 1,
          visits: 1,
          visit_duration: 100,
          bounces: 0
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
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&detailed=true&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Google",
                 "visitors" => 3,
                 "bounce_rate" => 25,
                 "visit_duration" => 450.0
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 50
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
               %{"name" => "Google", "visitors" => 2},
               %{"name" => "DuckDuckGo", "visitors" => 1}
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
        ),
        build(:imported_sources,
          source: "DuckDuckGo"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources?limit=1&page=2")

      assert json_response(conn, 200) == [
               %{"name" => "DuckDuckGo", "visitors" => 1}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/sources?limit=1&page=2&with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "DuckDuckGo", "visitors" => 2}
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
               %{"name" => "Google", "visitors" => 1}
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_mediums" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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

      populate_stats(site, [
        build(:imported_sources,
          utm_medium: "social",
          date: ~D[2021-01-01],
          visit_duration: 700,
          bounces: 1,
          visits: 1,
          visitors: 1
        ),
        build(:imported_sources,
          utm_medium: "email",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 100
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
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               },
               %{
                 "name" => "email",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "social",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0
               },
               %{
                 "name" => "email",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 50
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_campaigns" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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

      populate_stats(site, [
        build(:imported_sources,
          utm_campaign: "profile",
          date: ~D[2021-01-01],
          visit_duration: 700,
          bounces: 1,
          visits: 1,
          visitors: 1
        ),
        build(:imported_sources,
          utm_campaign: "august",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
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
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "profile",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "august",
                 "visitors" => 3,
                 "bounce_rate" => 67,
                 "visit_duration" => 300
               },
               %{
                 "name" => "profile",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0
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
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "Twitter",
                 "visitors" => 1,
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

      # Imported data is ignored when filtering
      populate_stats(site, [
        build(:imported_sources, source: "Twitter")
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Twitter",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
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
               %{
                 "name" => "Twitter",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
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
                 %{"name" => "10words.com", "visitors" => 2},
                 %{"name" => "10words.com/page1", "visitors" => 1}
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
                   "visitors" => 2,
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
                 %{
                   "name" => "10words.com",
                   "total_visitors" => 2,
                   "conversion_rate" => 50.0,
                   "visitors" => 1
                 }
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
                 %{
                   "name" => "10words.com",
                   "total_visitors" => 2,
                   "conversion_rate" => 50.0,
                   "visitors" => 1
                 }
               ]
             }
    end
  end

  describe "GET /api/stats/:domain/utm_terms" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns top utm_terms by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_term: "oat milk",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_term: "oat milk",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          utm_term: "Sweden",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_term: "Sweden",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      populate_stats(site, [
        build(:imported_sources,
          utm_term: "oat milk",
          date: ~D[2021-01-01],
          visit_duration: 700,
          bounces: 1,
          visits: 1,
          visitors: 1
        ),
        build(:imported_sources,
          utm_term: "Sweden",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Sweden",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Sweden",
                 "visitors" => 3,
                 "bounce_rate" => 67,
                 "visit_duration" => 300
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_contents" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns top utm_contents by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_content: "ad",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_content: "ad",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          utm_content: "blog",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_content: "blog",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      populate_stats(site, [
        build(:imported_sources,
          utm_content: "ad",
          date: ~D[2021-01-01],
          visit_duration: 700,
          bounces: 1,
          visits: 1,
          visitors: 1
        ),
        build(:imported_sources,
          utm_content: "blog",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "blog",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               },
               %{
                 "name" => "ad",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "blog",
                 "visitors" => 3,
                 "bounce_rate" => 67,
                 "visit_duration" => 300
               },
               %{
                 "name" => "ad",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0
               }
             ]
    end
  end
end
