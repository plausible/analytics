defmodule PlausibleWeb.Api.StatsController.SourcesTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  defp query_sources(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:source"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "relative_date" => Keyword.get(opts, :relative_date, nil),
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

      response = query_sources(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [3, 50.0]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [2, 33.33]},
               %{"dimensions" => ["Direct / None"], "metrics" => [1, 16.67]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
             ]

      assert response["query"]["date_range"] == [
               "2021-01-01T00:00:00Z",
               "2021-01-01T23:59:59Z"
             ]
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:props:author", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Facebook"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:author", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
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

      response1 = query_sources(conn, site, date_range: "day")

      assert response1["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
             ]

      response2 = query_sources(conn, site, date_range: "day", include: %{"imports" => true})

      assert response2["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [4, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [2, 33.33]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          order_by: [["visit_duration", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 100, 0, 50.0]},
               %{"dimensions" => ["Google"], "metrics" => [1, 0, 900, 50.0]}
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

      response1 =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          order_by: [["visit_duration", "asc"]]
        )

      assert response1["results"] == [
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 100, 0, 50.0]},
               %{"dimensions" => ["Google"], "metrics" => [1, 0, 900, 50.0]}
             ]

      response2 =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [3, 25.0, 450.0, 60.0]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [2, 50.0, 50.0, 40.0]}
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

      response = query_sources(conn, site, date_range: "realtime")

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
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

      response1 =
        query_sources(conn, site, date_range: "day", pagination: %{"limit" => 1, "offset" => 1})

      assert response1["results"] == [
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
             ]

      response2 =
        query_sources(conn, site,
          date_range: "day",
          pagination: %{"limit" => 1, "offset" => 1},
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]}
             ]
    end

    test "shows sources for a page", %{conn: conn, site: site} do
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

      response =
        query_sources(conn, site,
          date_range: "day",
          filters: [["is", "event:page", ["/page1"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 33.33]}
             ]
    end

    test "order_by [[visit:source, desc]] is respected", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "C"),
        build(:pageview, referrer_source: "A"),
        build(:pageview, referrer_source: "B")
      ])

      response =
        query_sources(conn, site,
          date_range: "day",
          order_by: [["visit:source", "desc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["C"], "metrics" => [1, 33.33]},
               %{"dimensions" => ["B"], "metrics" => [1, 33.33]},
               %{"dimensions" => ["A"], "metrics" => [1, 33.33]}
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

      response1 =
        query_sources(conn, site,
          date_range: ["2024-08-10", "2024-08-10"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          order_by: [["visit_duration", "asc"], ["visit:source", "desc"]]
        )

      assert response1["results"] == [
               %{"dimensions" => ["Z"], "metrics" => [1, 100, 0, 25.0]},
               %{"dimensions" => ["A"], "metrics" => [2, 100, 0, 50.0]},
               %{"dimensions" => ["C"], "metrics" => [1, 0, 30, 25.0]},
               %{"dimensions" => ["B"], "metrics" => [1, 0, 45, 25.0]}
             ]

      response2 =
        query_sources(conn, site,
          date_range: ["2024-08-10", "2024-08-10"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          order_by: [["visit_duration", "desc"], ["visit:source", "asc"]]
        )

      assert response2["results"] == [
               %{"dimensions" => ["B"], "metrics" => [1, 0, 45, 25.0]},
               %{"dimensions" => ["C"], "metrics" => [1, 0, 30, 25.0]},
               %{"dimensions" => ["A"], "metrics" => [2, 100, 0, 50.0]},
               %{"dimensions" => ["Z"], "metrics" => [1, 100, 0, 25.0]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-02", "2021-01-02"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          include: %{"compare" => "previous_period"}
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Google"],
                 "metrics" => [2, 100, 0, 66.67],
                 "comparison" => %{
                   "dimensions" => ["Google"],
                   "metrics" => [0, 0, nil, 0.0],
                   "change" => [100, nil, nil, 100]
                 }
               },
               %{
                 "dimensions" => ["DuckDuckGo"],
                 "metrics" => [1, 100, 0, 33.33],
                 "comparison" => %{
                   "dimensions" => ["DuckDuckGo"],
                   "metrics" => [1, 100, 0, 100.0],
                   "change" => [0, 0, 0, -67]
                 }
               }
             ]

      assert response["query"]["date_range"] == [
               "2021-01-02T00:00:00Z",
               "2021-01-02T23:59:59Z"
             ]

      assert response["query"]["comparison_date_range"] == [
               "2021-01-01T00:00:00Z",
               "2021-01-01T23:59:59Z"
             ]
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

      response =
        query_sources(conn, site,
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]]],
          order_by: [["visitors", "desc"], ["visit:source", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Direct / None"],
                 "metrics" => [
                   2,
                   100.0,
                   2,
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
                 "dimensions" => ["Google"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["DuckDuckGo"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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

  describe "UTM parameters with hostname filter" do
    setup [:create_user, :log_in, :create_site]

    for {resource, attr, dimension} <- [
          {:utm_campaigns, :utm_campaign, "visit:utm_campaign"},
          {:utm_sources, :utm_source, "visit:utm_source"},
          {:utm_terms, :utm_term, "visit:utm_term"},
          {:utm_contents, :utm_content, "visit:utm_content"}
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

        response =
          query_sources(conn, site,
            dimensions: [unquote(dimension)],
            date_range: ["2021-01-01", "2021-01-01"],
            filters: [["is", "event:hostname", ["one.example.com"]]]
          )

        # nobody landed on one.example.com from utm_param=ad
        assert response["results"] == []
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:channel"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Paid Social"], "metrics" => [2, 100, 0, 66.67]},
               %{"dimensions" => ["Organic Search"], "metrics" => [1, 0, 900, 33.33]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:channel"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]]],
          order_by: [["visitors", "desc"], ["visit:channel", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Direct"],
                 "metrics" => [
                   2,
                   100.0,
                   2,
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
                 "dimensions" => ["Organic Search"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["Paid Social"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 800,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_medium"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"],
          order_by: [["visit:utm_medium", "asc"]]
        )

      assert response1["results"] == [
               %{"dimensions" => ["email"], "metrics" => [1, 100, 0, 50.0]},
               %{"dimensions" => ["social"], "metrics" => [1, 0, 900, 50.0]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_medium"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"],
          order_by: [["visit:utm_medium", "asc"]],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["email"], "metrics" => [2, 50, 50, 50.0]},
               %{"dimensions" => ["social"], "metrics" => [2, 50, 800.0, 50.0]}
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 800,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_medium"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_medium", [""]]],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["social"], "metrics" => [1, 0, 900, 100.0]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_medium"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_medium", [""]]],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["social"], "metrics" => [2, 50.0, 800.0, 100.0]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_medium"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:utm_medium", [""]]],
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["social"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["email"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_campaign"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["august"], "metrics" => [2, 100, 0, 66.67]},
               %{"dimensions" => ["profile"], "metrics" => [1, 0, 900, 33.33]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_campaign"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["august"], "metrics" => [3, 67, 300, 60.0]},
               %{"dimensions" => ["profile"], "metrics" => [2, 50, 800.0, 40.0]}
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_campaign"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_campaign", [""]]],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["profile"], "metrics" => [1, 0, 900, 100.0]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_campaign"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_campaign", [""]]],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["profile"], "metrics" => [2, 50.0, 800.0, 100.0]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_campaign"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:utm_campaign", [""]]],
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["profile"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["august"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_source"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response["results"] == [
               %{"dimensions" => ["newsletter"], "metrics" => [2, 100, 0, 66.67]},
               %{"dimensions" => ["Twitter"], "metrics" => [1, 0, 900, 33.33]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_source"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:utm_source", [""]]],
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Twitter"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["newsletter"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_term"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["Sweden"], "metrics" => [2, 100, 0, 66.67]},
               %{"dimensions" => ["oat milk"], "metrics" => [1, 0, 900, 33.33]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_term"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["Sweden"], "metrics" => [3, 67.0, 300.0, 60.0]},
               %{"dimensions" => ["oat milk"], "metrics" => [2, 50.0, 800.0, 40.0]}
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_term"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_term", [""]]],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["oat milk"], "metrics" => [1, 0, 900, 100.0]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_term"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_term", [""]]],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["oat milk"], "metrics" => [2, 50.0, 800.0, 100.0]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_term"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:utm_term", [""]]],
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["oat milk"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["Sweden"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_content"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["blog"], "metrics" => [2, 100, 0, 66.67]},
               %{"dimensions" => ["ad"], "metrics" => [1, 0, 900, 33.33]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_content"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["blog"], "metrics" => [3, 67.0, 300.0, 60.0]},
               %{"dimensions" => ["ad"], "metrics" => [2, 50.0, 800.0, 40.0]}
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visit_duration: 1600,
          bounces: 1,
          visits: 2,
          visitors: 2
        ),
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

      response1 =
        query_sources(conn, site,
          dimensions: ["visit:utm_content"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_content", [""]]],
          date_range: ["2021-01-01", "2021-01-01"]
        )

      assert response1["results"] == [
               %{"dimensions" => ["ad"], "metrics" => [1, 0, 900, 100.0]}
             ]

      response2 =
        query_sources(conn, site,
          dimensions: ["visit:utm_content"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"],
          filters: [["is_not", "visit:utm_content", [""]]],
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert response2["results"] == [
               %{"dimensions" => ["ad"], "metrics" => [2, 50.0, 800.0, 100.0]}
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

      response =
        query_sources(conn, site,
          dimensions: ["visit:utm_content"],
          date_range: "day",
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:utm_content", [""]]],
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["ad"],
                 "metrics" => [
                   2,
                   66.67,
                   3,
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
                 "dimensions" => ["blog"],
                 "metrics" => [
                   1,
                   50.0,
                   2,
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

      response =
        query_sources(conn, site,
          date_range: "day",
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [["is", "event:goal", ["Signup"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Twitter"], "metrics" => [1, 50.0, 2]}
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

      response =
        query_sources(conn, site,
          date_range: "day",
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [
            ["is", "event:goal", ["Signup"]],
            ["is", "event:hostname", ["app.example.com"]]
          ]
        )

      assert response["results"] == []
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

      response =
        query_sources(conn, site,
          date_range: "day",
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [
            ["is", "event:goal", ["Signup"]],
            ["is", "event:hostname", ["app.example.com"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["Facebook"], "metrics" => [1, 100.0, 1]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [
            ["is", "event:goal", ["Download"]],
            ["is", "event:props:logged_in", ["true"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 50.0, 2]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [
            ["is", "event:goal", ["Download"]],
            ["is_not", "event:props:logged_in", ["true"]]
          ],
          order_by: [["visit:source", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["DuckDuckGo"], "metrics" => [1, 100.0, 1]},
               %{"dimensions" => ["Google"], "metrics" => [1, 50.0, 2]}
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

      response =
        query_sources(conn, site,
          date_range: "day",
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          filters: [["is", "event:goal", ["Visit /register"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Twitter"], "metrics" => [1, 50.0, 2]}
             ]
    end
  end

  describe "GET /api/stats/:domain/referrer-drilldown (Google Search Terms)" do
    setup [:create_user, :log_in, :create_site]

    test "gets keywords from Google", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day")

      assert %{
               "results" => [
                 %{
                   "name" => "simple web analytics",
                   "visitors" => 25,
                   "impressions" => 50,
                   "position" => 2.0,
                   "ctr" => 37.0
                 },
                 %{
                   "name" => "open-source analytics",
                   "visitors" => 15,
                   "impressions" => 25,
                   "position" => 4.0,
                   "ctr" => 50.0
                 }
               ]
             } = json_response(conn, 200)
    end

    test "returns 200 with empty keywords list when no data returned from last 30d", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/empty"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=30d&filters=#{filters}")

      assert json_response(conn, 200) == %{"results" => []}
    end

    test "returns 422 with error when no data returned and queried range is too recent", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/empty"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day&filters=#{filters}")

      assert json_response(conn, 422) == %{"error_code" => "period_too_recent"}
    end

    test "returns 422 with error when Google account not connected (admin)", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/not-configured"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day&filters=#{filters}")

      assert %{"error_code" => "not_configured", "is_admin" => true} = json_response(conn, 422)
    end

    test "returns 422 with error when Google account not connected (non-admin)", %{conn: conn} do
      site = new_site(public: true)

      filters = Jason.encode!([[:is, "event:page", ["/not-configured"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day&filters=#{filters}")

      %{
        "error_code" => "not_configured",
        "is_admin" => false
      } = json_response(conn, 422)
    end

    test "returns 422 with error when unsupported filters used", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "event:page", ["/unsupported-filters"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day&filters=#{filters}")

      assert %{"error_code" => "unsupported_filters"} = json_response(conn, 422)
    end

    @tag :capture_log
    test "returns 502 when Google API responds with an unexpected error", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/unexpected-error"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/google-search-terms?period=day&filters=#{filters}")

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

      response =
        query_sources(conn, site,
          date_range: "day",
          dimensions: ["visit:referrer"],
          filters: [["is", "visit:source", ["10words"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["10words.com"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["10words.com/page1"], "metrics" => [1, 33.33]}
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

      response =
        query_sources(conn, site,
          date_range: "day",
          dimensions: ["visit:referrer"],
          filters: [
            ["is", "visit:source", ["example"]],
            ["is", "event:hostname", ["one.example.com"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["example.com/page1"], "metrics" => [1, 100.0]}
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

      response =
        query_sources(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:referrer"],
          filters: [["is", "visit:source", ["10words"]]],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["10words.com"], "metrics" => [2, 50.0, 450, 100.0]}
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

      response =
        query_sources(conn, site,
          date_range: "day",
          dimensions: ["visit:referrer"],
          filters: [
            ["is", "visit:source", ["10words"]],
            ["is", "event:goal", ["Signup"]]
          ],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["10words.com"], "metrics" => [1, 2, 50.0]}
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

      response =
        query_sources(conn, site,
          date_range: "day",
          dimensions: ["visit:referrer"],
          filters: [
            ["is", "visit:source", ["10words"]],
            ["is", "event:goal", ["Visit /register"]]
          ],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["10words.com"], "metrics" => [1, 2, 50.0]}
             ]
    end
  end
end
