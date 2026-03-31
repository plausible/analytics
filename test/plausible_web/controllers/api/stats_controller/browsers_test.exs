defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase

  defp query_browsers(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:browser"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "percentage"]),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_site, :create_site_import]

    test "returns top browsers by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Firefox")
      ])

      response = query_browsers(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Firefox"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns top browsers with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          browser: "Chrome"
        ),
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          browser: "Firefox",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          browser: "Safari"
        )
      ])

      response =
        query_browsers(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [1, 100.0]}
             ]
    end

    test "returns top browsers with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          browser: "Firefox",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          browser: "Safari"
        )
      ])

      response =
        query_browsers(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["John Doe"]]],
          order_by: [["visit:browser", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Firefox"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["Safari"], "metrics" => [1, 50.0]}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, browser: "Chrome"),
        build(:pageview, user_id: 2, browser: "Chrome"),
        build(:event, user_id: 1, name: "Signup")
      ])

      response =
        query_browsers(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [1, 2, 50.0]}
             ]
    end

    test "returns top browsers including imported data", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview, browser: "Chrome"),
        build(:imported_browsers, browser: "Chrome"),
        build(:imported_browsers, browser: "Firefox"),
        build(:imported_visitors, visitors: 2)
      ])

      response1 = query_browsers(conn, site, date_range: "day")

      assert response1["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [1, 100.0]}
             ]

      response2 =
        query_browsers(conn, site, date_range: "day", include: %{"imports" => true})

      assert response2["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Firefox"], "metrics" => [1, 33.33]}
             ]
    end

    test "skips breakdown when visitors=0 (possibly due to 'Enable Users Metric' in GA)", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_browsers, browser: "Chrome", visitors: 0, visits: 14),
        build(:imported_browsers, browser: "Firefox", visitors: 0, visits: 14),
        build(:imported_browsers,
          browser: "''",
          visitors: 0,
          visits: 14,
          visit_duration: 0,
          bounces: 14
        )
      ])

      response =
        query_browsers(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == []
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          browser: ""
        )
      ])

      response = query_browsers(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [1, 100.0]}
             ]
    end

    test "select empty imported_browsers as (not set), merging with the native (not set)", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 123),
        build(:imported_browsers, visitors: 1),
        build(:imported_visitors, visitors: 1)
      ])

      response =
        query_browsers(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [2, 100.0]}
             ]
    end

    test "returns comparisons", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00])
      ])

      response =
        query_browsers(conn, site,
          date_range: ["2021-01-07", "2021-01-13"],
          include: %{"compare" => "previous_period"}
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Chrome"],
                 "metrics" => [2, 66.67],
                 "comparison" => %{
                   "dimensions" => ["Chrome"],
                   "metrics" => [0, 0.0],
                   "change" => [100, 100]
                 }
               },
               %{
                 "dimensions" => ["Firefox"],
                 "metrics" => [1, 33.33],
                 "comparison" => %{
                   "dimensions" => ["Firefox"],
                   "metrics" => [1, 50.0],
                   "change" => [0, -33]
                 }
               }
             ]

      assert response["query"]["date_range"] == [
               "2021-01-07T00:00:00Z",
               "2021-01-13T23:59:59Z"
             ]

      assert response["query"]["comparison_date_range"] == [
               "2020-12-31T00:00:00Z",
               "2021-01-06T23:59:59Z"
             ]
    end

    test "returns comparisons with limit", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00])
      ])

      response =
        query_browsers(conn, site,
          date_range: ["2021-01-06", "2021-01-12"],
          include: %{"compare" => "previous_period"},
          pagination: %{"limit" => 1}
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Chrome"],
                 "metrics" => [2, 66.67],
                 "comparison" => %{
                   "dimensions" => ["Chrome"],
                   "metrics" => [1, 25.0],
                   "change" => [100, 167]
                 }
               }
             ]

      assert response["query"]["date_range"] == [
               "2021-01-06T00:00:00Z",
               "2021-01-12T23:59:59Z"
             ]

      assert response["query"]["comparison_date_range"] == [
               "2020-12-30T00:00:00Z",
               "2021-01-05T23:59:59Z"
             ]
    end

    @tag :ee_only
    test "return revenue metrics for browsers breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, browser: "Firefox"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, browser: "Firefox"),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, browser: "Firefox"),
        build(:pageview, user_id: 4, browser: "Safari"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 5, browser: "Safari"),
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

      response =
        query_browsers(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "total_visitors",
            "group_conversion_rate",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:browser", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["(not set)"],
                 "metrics" => [
                   2,
                   2,
                   100.0,
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Firefox"],
                 "metrics" => [
                   2,
                   3,
                   66.67,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Safari"],
                 "metrics" => [
                   1,
                   2,
                   50.0,
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   }
                 ]
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/browser-versions" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns correct conversion_rate when browser_version clashes across browsers", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, browser: "Chrome", browser_version: "110", name: "Signup"),
        build(:event, browser: "Chrome", browser_version: "110", name: "Signup"),
        build(:pageview, browser: "Chrome", browser_version: "110"),
        build(:pageview, browser: "Chrome", browser_version: "121"),
        build(:pageview, browser: "Chrome", browser_version: "121"),
        build(:event, browser: "Firefox", browser_version: "121", name: "Signup"),
        build(:pageview, browser: "Firefox", browser_version: "110"),
        build(:pageview, browser: "Firefox", browser_version: "110"),
        build(:pageview, browser: "Firefox", browser_version: "110"),
        build(:pageview, browser: "Firefox", browser_version: "110")
      ])

      insert(:goal, site: site, event_name: "Signup")

      response =
        query_browsers(conn, site,
          date_range: "day",
          dimensions: ["visit:browser", "visit:browser_version"],
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert List.first(response["results"]) == %{
               "dimensions" => ["Chrome", "110"],
               "metrics" => [2, 3, 66.67]
             }

      assert List.last(response["results"]) == %{
               "dimensions" => ["Firefox", "121"],
               "metrics" => [1, 1, 100.0]
             }
    end

    test "returns top browser versions by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome", browser_version: "78.0"),
        build(:pageview, browser: "Chrome", browser_version: "78.0"),
        build(:pageview, browser: "Chrome", browser_version: "77.0"),
        build(:pageview, browser: "Firefox", browser_version: "88.0")
      ])

      response =
        query_browsers(conn, site,
          date_range: "day",
          dimensions: ["visit:browser", "visit:browser_version"],
          filters: [["is", "visit:browser", ["Chrome"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Chrome", "78.0"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Chrome", "77.0"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns browser and version with additional metrics", %{conn: conn, site: site} do
      populate_stats(site, [build(:pageview, browser: "Chrome", browser_version: "78.0")])

      response =
        query_browsers(conn, site,
          date_range: "day",
          dimensions: ["visit:browser", "visit:browser_version"],
          filters: [["is", "visit:browser", ["Chrome"]]],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Chrome", "78.0"], "metrics" => [1, 100, 0, 100.0]}
             ]
    end

    test "returns results for (not set)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "", browser_version: "")
      ])

      response =
        query_browsers(conn, site,
          date_range: "day",
          dimensions: ["visit:browser", "visit:browser_version"],
          filters: [["is", "visit:browser", ["(not set)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["(not set)", "(not set)"], "metrics" => [1, 100.0]}
             ]
    end

    test "with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          browser: "Chrome",
          browser_version: "121",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          browser: "Chrome",
          browser_version: "110",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:imported_browsers,
          date: ~D[2021-01-01],
          browser: "Chrome",
          browser_version: "121",
          visitors: 5
        ),
        build(:imported_browsers,
          date: ~D[2021-01-01],
          browser: "Firefox",
          browser_version: "121",
          visitors: 3
        ),
        build(:imported_browsers, date: ~D[2021-01-01], visitors: 10),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 18)
      ])

      response =
        query_browsers(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:browser", "visit:browser_version"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["(not set)", "(not set)"], "metrics" => [10, 50.0]},
               %{"dimensions" => ["Chrome", "121"], "metrics" => [6, 30.0]},
               %{"dimensions" => ["Firefox", "121"], "metrics" => [3, 15.0]},
               %{"dimensions" => ["Chrome", "110"], "metrics" => [1, 5.0]}
             ]
    end
  end
end
