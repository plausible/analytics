defmodule PlausibleWeb.Api.StatsController.SourcesTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  describe "GET /api/stats/:domain/sources" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        ),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 3, "percentage" => 50.0},
               %{"name" => "DuckDuckGo", "visitors" => 2, "percentage" => 33.33},
               %{"name" => "Direct / None", "visitors" => 1, "percentage" => 16.67}
             ]
    end

    test "returns top sources with :is filter on custom pageview props", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]

      assert json_response(conn, 200)["meta"] == %{
               "date_range_label" => "1 Jan 2021"
             }
    end

    test "returns top sources with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["other"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "returns top sources with :is (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Facebook", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "returns top sources with :is_not (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          "meta.key": ["logged_in"],
          "meta.value": ["true"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["other"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["author"],
          "meta.value": ["another"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "returns top sources with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "Google", referrer: "google.com"),
        build(:pageview, referrer_source: "Google", referrer: "google.com"),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        )
      ])

      populate_stats(site, [
        build(:imported_visitors),
        build(:imported_visitors),
        build(:imported_visitors),
        build(:imported_sources,
          source: "Google",
          visitors: 2
        ),
        build(:imported_sources,
          source: "DuckDuckGo",
          visitors: 1
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/sources?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]

      conn2 = get(conn, "/api/stats/#{site.domain}/sources?period=day&with_imported=true")

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "Google", "visitors" => 4, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 2, "percentage" => 33.33}
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

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 50.0
               },
               %{
                 "name" => "Google",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 50.0
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
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-01]),
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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&detailed=true"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 50.0
               },
               %{
                 "name" => "Google",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 50.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&detailed=true&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "Google",
                 "visitors" => 3,
                 "bounce_rate" => 25.0,
                 "visit_duration" => 450.0,
                 "percentage" => 60.0
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 50.0,
                 "percentage" => 40.0
               }
             ]
    end

    test "returns top sources in realtime report", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: relative_time(minute: -3)
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: relative_time(minute: -2)
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: relative_time(minute: -1)
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/sources?period=realtime")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
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
        ),
        build(:imported_sources,
          source: "DuckDuckGo"
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/sources?period=day&limit=1&page=2")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&limit=1&page=2&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67}
             ]
    end

    test "shows sources for a page (using old page filter)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/page1", referrer_source: "Google"),
        build(:pageview, pathname: "/page1", referrer_source: "Google"),
        build(:pageview,
          user_id: 1,
          pathname: "/page2",
          referrer_source: "DuckDuckGo"
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/page1",
          referrer_source: "DuckDuckGo"
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/page1"]]])
      conn = get(conn, "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "shows sources for a page (using new filters)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/page1", referrer_source: "Google"),
        build(:pageview, pathname: "/page1", referrer_source: "Google"),
        build(:pageview,
          user_id: 1,
          pathname: "/page2",
          referrer_source: "DuckDuckGo"
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/page1",
          referrer_source: "DuckDuckGo"
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/page1"]]])
      conn = get(conn, "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Google", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "DuckDuckGo", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "order_by [[visit:source, desc]] is respected", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "C"),
        build(:pageview, referrer_source: "A"),
        build(:pageview, referrer_source: "B")
      ])

      order_by = Jason.encode!([["visit:source", "desc"]])
      conn = get(conn, "/api/stats/#{site.domain}/sources?order_by=#{order_by}&period=day")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "C", "visitors" => 1, "percentage" => 33.33},
               %{"name" => "B", "visitors" => 1, "percentage" => 33.33},
               %{"name" => "A", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "order_by [[visit_duration, asc], [visit:source, desc]]] is respected and flipping the sort orders works",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/in",
          user_id: @user_id,
          referrer_source: "B",
          timestamp: ~N[2024-08-10 09:00:00]
        ),
        build(:pageview,
          pathname: "/out",
          user_id: @user_id,
          referrer_source: "B",
          timestamp: ~N[2024-08-10 09:00:45]
        ),
        build(:pageview,
          pathname: "/in",
          user_id: @user_id,
          referrer_source: "C",
          timestamp: ~N[2024-08-10 10:00:00]
        ),
        build(:pageview,
          pathname: "/out",
          user_id: @user_id,
          referrer_source: "C",
          timestamp: ~N[2024-08-10 10:00:30]
        ),
        build(:pageview, referrer_source: "A", timestamp: ~N[2024-08-10 10:00:30]),
        build(:pageview, referrer_source: "A", timestamp: ~N[2024-08-10 10:00:30]),
        build(:pageview, referrer_source: "Z", timestamp: ~N[2024-08-10 10:00:30])
      ])

      order_by_asc = Jason.encode!([["visit_duration", "asc"], ["visit:source", "desc"]])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2024-08-10&detailed=true&order_by=#{order_by_asc}"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "Z",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 25.0
               },
               %{
                 "name" => "A",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 50.0
               },
               %{
                 "name" => "C",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 30,
                 "percentage" => 25.0
               },
               %{
                 "name" => "B",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 45,
                 "percentage" => 25.0
               }
             ]

      order_by_flipped = Jason.encode!([["visit_duration", "desc"], ["visit:source", "asc"]])

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2024-08-10&detailed=true&order_by=#{order_by_flipped}"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "B",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 45,
                 "percentage" => 25.0
               },
               %{
                 "name" => "C",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 30,
                 "percentage" => 25.0
               },
               %{
                 "name" => "A",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 50.0
               },
               %{
                 "name" => "Z",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 25.0
               }
             ]
    end

    test "can compare with previous period", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: ~N[2021-01-02 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: ~N[2021-01-02 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: ~N[2021-01-02 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-02&comparison=previous_period&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Google",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67,
                 "comparison" => %{
                   "visitors" => 0,
                   "bounce_rate" => 0,
                   "visit_duration" => nil,
                   "percentage" => 0.0,
                   "change" => %{
                     "visitors" => 100,
                     "bounce_rate" => nil,
                     "visit_duration" => nil,
                     "percentage" => 100
                   }
                 }
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 33.33,
                 "comparison" => %{
                   "visitors" => 1,
                   "bounce_rate" => 100,
                   "visit_duration" => 0,
                   "percentage" => 100.0,
                   "change" => %{
                     "visitors" => 0,
                     "bounce_rate" => 0,
                     "visit_duration" => 0,
                     "percentage" => -67
                   }
                 }
               }
             ]

      assert json_response(conn, 200)["meta"] == %{
               "date_range_label" => "2 Jan 2021",
               "comparison_date_range_label" => "1 Jan 2021"
             }
    end

    @tag :ee_only
    test "return revenue metrics for sources breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          user_id: 4,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        ),
        build(:pageview,
          user_id: 8,
          referrer_source: "Bing",
          referrer: "bing.com"
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/sources#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Direct / None",
                 "visitors" => 2,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "conversion_rate" => 100.0,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "total_visitors" => 2
               },
               %{
                 "name" => "Google",
                 "visitors" => 2,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3
               },
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2
               }
             ]
    end
  end

  describe "UTM parameters with hostname filter" do
    setup [:create_user, :log_in, :create_site]

    for {resource, attr} <- [
          utm_campaigns: :utm_campaign,
          utm_sources: :utm_source,
          utm_terms: :utm_term,
          utm_contents: :utm_content
        ] do
      test "returns #{resource} when filtered by hostname", %{conn: conn, site: site} do
        populate_stats(site, [
          # session starts at two.example.com with utm_param=ad
          build(
            :pageview,
            [
              {unquote(attr), "ad"},
              {:user_id, @user_id},
              {:hostname, "two.example.com"},
              {:timestamp, ~N[2021-01-01 00:00:00]}
            ]
          ),
          # session continues on one.example.com without any utm_params
          build(
            :pageview,
            [
              {:user_id, @user_id},
              {:hostname, "one.example.com"},
              {:timestamp, ~N[2021-01-01 00:15:00]}
            ]
          )
        ])

        filters = Jason.encode!([[:is, "event:hostname", ["one.example.com"]]])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/#{unquote(resource)}?period=day&date=2021-01-01&filters=#{filters}"
          )

        # nobody landed on one.example.com from utm_param=ad
        assert json_response(conn, 200)["results"] == []
      end
    end
  end

  describe "GET /api/stats/:domain/channels" do
    setup [:create_user, :log_in, :create_site]

    test "returns top channels by unique user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Bing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Bing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          utm_source: "fb-ads",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Facebook",
          utm_source: "fb-ads",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/channels?period=day&&detailed=true&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "Paid Social",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67
               },
               %{
                 "name" => "Organic Search",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 33.33
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for channels breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          referrer_source: "Google",
          referrer: "google.com"
        ),
        build(:pageview,
          user_id: 4,
          referrer_source: "Facebook",
          utm_source: "fb-ads"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          referrer_source: "Facebook",
          utm_source: "fb-ads"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/channels#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Direct",
                 "visitors" => 2,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "conversion_rate" => 100.0,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "total_visitors" => 2
               },
               %{
                 "name" => "Organic Search",
                 "visitors" => 2,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3
               },
               %{
                 "name" => "Paid Social",
                 "visitors" => 1,
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_mediums" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "email",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 50.0
               },
               %{
                 "name" => "social",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 50.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "email",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 50,
                 "percentage" => 50.0
               },
               %{
                 "name" => "social",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0,
                 "percentage" => 50.0
               }
             ]
    end

    test "filters out entries without utm_medium present", %{conn: conn, site: site} do
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
          utm_medium: "",
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
          utm_medium: "",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 100
        )
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "social",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 100.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "social",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 100.0
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for UTM mediums breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          utm_medium: "social"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          utm_medium: "social"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          utm_medium: "social"
        ),
        build(:pageview,
          user_id: 4,
          utm_medium: "email"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          utm_medium: "email"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/utm_mediums#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "social",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "email",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_campaigns" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "august",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67
               },
               %{
                 "name" => "profile",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 33.33
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "august",
                 "visitors" => 3,
                 "bounce_rate" => 67,
                 "visit_duration" => 300,
                 "percentage" => 60.0
               },
               %{
                 "name" => "profile",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 800.0,
                 "percentage" => 40.0
               }
             ]
    end

    test "filters out entries without utm_campaign present", %{conn: conn, site: site} do
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
          utm_campaign: "",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_campaign: "",
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
          utm_campaign: "",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
        )
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "profile",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 100.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "profile",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 100.0
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for UTM campaigns breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          utm_campaign: "profile"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          utm_campaign: "profile"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          utm_campaign: "profile"
        ),
        build(:pageview,
          user_id: 4,
          utm_campaign: "august"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          utm_campaign: "august"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/utm_campaigns#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "profile",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "august",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_sources" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "newsletter",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67
               },
               %{
                 "name" => "Twitter",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 33.33
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for UTM sources breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          utm_source: "Twitter"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          utm_source: "Twitter"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          utm_source: "Twitter"
        ),
        build(:pageview,
          user_id: 4,
          utm_source: "newsletter"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          utm_source: "newsletter"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/utm_sources#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "Twitter",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "newsletter",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_terms" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "Sweden",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 33.33
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "Sweden",
                 "visitors" => 3,
                 "bounce_rate" => 67.0,
                 "visit_duration" => 300.0,
                 "percentage" => 60.0
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 40.0
               }
             ]
    end

    test "filters out entries without utm_term present", %{conn: conn, site: site} do
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
          utm_term: "",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_term: "",
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
          utm_term: "",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
        )
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "oat milk",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 100.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "oat milk",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 100.0
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for UTM terms breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          utm_term: "oat milk"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          utm_term: "oat milk"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          utm_term: "oat milk"
        ),
        build(:pageview,
          user_id: 4,
          utm_term: "Sweden"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          utm_term: "Sweden"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/utm_terms#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "oat milk",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "Sweden",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/utm_contents" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "blog",
                 "visitors" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 66.67
               },
               %{
                 "name" => "ad",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 33.33
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "blog",
                 "visitors" => 3,
                 "bounce_rate" => 67.0,
                 "visit_duration" => 300.0,
                 "percentage" => 60.0
               },
               %{
                 "name" => "ad",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 40.0
               }
             ]
    end

    test "filters out entries without utm_content present", %{conn: conn, site: site} do
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
          utm_content: "",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_content: "",
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
          utm_content: "",
          date: ~D[2021-01-01],
          bounces: 0,
          visits: 1,
          visitors: 1,
          visit_duration: 900
        )
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "name" => "ad",
                 "visitors" => 1,
                 "bounce_rate" => 0,
                 "visit_duration" => 900,
                 "percentage" => 100.0
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "ad",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 800.0,
                 "percentage" => 100.0
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for UTM contents breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          utm_content: "ad"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          utm_content: "ad"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          utm_content: "ad"
        ),
        build(:pageview,
          user_id: 4,
          utm_content: "blog"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          utm_content: "blog"
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/utm_contents#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "ad",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "blog",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/sources - with goal filter" do
    setup [:create_user, :log_in, :create_site]

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

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Twitter",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns no top referrers for a custom goal and filtered by hostname",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview,
          hostname: "blog.example.com",
          referrer_source: "Facebook",
          user_id: @user_id
        ),
        build(:pageview,
          hostname: "app.example.com",
          pathname: "/register",
          user_id: @user_id
        ),
        build(:event,
          name: "Signup",
          hostname: "app.example.com",
          pathname: "/register",
          user_id: @user_id
        )
      ])

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Signup"]],
          [:is, "event:hostname", ["app.example.com"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == []
    end

    test "returns top referrers for a custom goal and filtered by hostname (2)",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview,
          hostname: "app.example.com",
          referrer_source: "Facebook",
          pathname: "/register",
          user_id: @user_id
        ),
        build(:event,
          name: "Signup",
          hostname: "app.example.com",
          pathname: "/register",
          user_id: @user_id
        )
      ])

      insert(:goal, site: site, event_name: "Signup")

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Signup"]],
          [:is, "event:hostname", ["app.example.com"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "conversion_rate" => 100.0,
                 "name" => "Facebook",
                 "total_visitors" => 1,
                 "visitors" => 1
               }
             ]
    end

    test "returns top referrers with goal filter + :is prop filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Download",
          "meta.key": ["method", "logged_in"],
          "meta.value": ["HTTP", "true"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          "meta.key": ["logged_in"],
          "meta.value": ["true"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          referrer_source: "Facebook",
          referrer: "facebook.com",
          name: "Download",
          "meta.key": ["method", "logged_in"],
          "meta.value": ["HTTP", "false"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      insert(:goal, site: site, event_name: "Download")

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Download"]],
          [:is, "event:props:logged_in", ["true"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "conversion_rate" => 50.0,
                 "total_visitors" => 2
               }
             ]
    end

    test "returns top referrers with goal filter + prop :is_not filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Download",
          "meta.key": ["method"],
          "meta.value": ["HTTP"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "Download",
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["method", "logged_in"],
          "meta.value": ["HTTP", "true"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Download",
          referrer_source: "Google",
          referrer: "google.com",
          "meta.key": ["method", "logged_in"],
          "meta.value": ["HTTP", "false"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      insert(:goal, site: site, event_name: "Download")

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Download"]],
          [:is_not, "event:props:logged_in", ["true"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "DuckDuckGo",
                 "visitors" => 1,
                 "conversion_rate" => 100.0,
                 "total_visitors" => 1
               },
               %{
                 "name" => "Google",
                 "visitors" => 1,
                 "conversion_rate" => 50.0,
                 "total_visitors" => 2
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

      insert(:goal, site: site, page_path: "/register")
      filters = Jason.encode!([[:is, "event:goal", ["Visit /register"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Twitter",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown (Google Search Terms)" do
    setup [:create_user, :log_in, :create_site]

    test "gets keywords from Google", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day")

      assert %{
               "results" => [
                 %{"name" => "simple web analytics", "count" => 6},
                 %{"name" => "open-source analytics", "count" => 2}
               ]
             } = json_response(conn, 200)
    end

    test "returns 200 with empty keywords list when no data returned from last 30d", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/empty"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=30d&filters=#{filters}")

      assert json_response(conn, 200) == %{"results" => []}
    end

    test "returns 422 with error when no data returned and queried range is too recent", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/empty"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&filters=#{filters}")

      assert json_response(conn, 422) == %{"error_code" => "period_too_recent"}
    end

    test "returns 422 with error when Google account not connected (admin)", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/not-configured"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&filters=#{filters}")

      assert %{"error_code" => "not_configured", "is_admin" => true} = json_response(conn, 422)
    end

    test "returns 422 with error when Google account not connected (non-admin)", %{conn: conn} do
      site = new_site(public: true)

      filters = Jason.encode!([[:is, "event:page", ["/not-configured"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&filters=#{filters}")

      %{
        "error_code" => "not_configured",
        "is_admin" => false
      } = json_response(conn, 422)
    end

    test "returns 422 with error when unsupported filters used", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "event:page", ["/unsupported-filters"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&filters=#{filters}")

      assert %{"error_code" => "unsupported_filters"} = json_response(conn, 422)
    end

    @tag :capture_log
    test "returns 502 when Google API responds with an unexpected error", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/unexpected-error"]]])

      conn = get(conn, "/api/stats/#{site.domain}/referrers/Google?period=day&filters=#{filters}")

      assert %{"error_code" => "not_configured"} = json_response(conn, 502)
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown" do
    setup [:create_user, :log_in, :create_site]

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

      assert json_response(conn, 200)["results"] == [
               %{"name" => "10words.com", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "10words.com/page1", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "returns top referrers for a particular source filtered by hostname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "example",
          referrer: "example.com",
          hostname: "two.example.com"
        ),
        build(:pageview,
          referrer_source: "example",
          referrer: "example.com",
          hostname: "two.example.com",
          user_id: @user_id
        ),
        build(:pageview,
          hostname: "one.example.com",
          user_id: @user_id
        ),
        build(:pageview,
          referrer_source: "example",
          referrer: "example.com/page1",
          hostname: "one.example.com"
        ),
        build(:pageview,
          referrer_source: "ignored",
          referrer: "ignored",
          hostname: "two.example.com"
        )
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["one.example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/example?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "example.com/page1", "visitors" => 1, "percentage" => 100.0}
             ]
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

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "10words.com",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 450,
                 "percentage" => 100.0
               }
             ]
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

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "10words.com",
                 "total_visitors" => 2,
                 "conversion_rate" => 50.0,
                 "visitors" => 1
               }
             ]
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

      insert(:goal, site: site, page_path: "/register")

      filters = Jason.encode!([[:is, "event:goal", ["Visit /register"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/referrers/10words?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "10words.com",
                 "total_visitors" => 2,
                 "conversion_rate" => 50.0,
                 "visitors" => 1
               }
             ]
    end
  end
end
