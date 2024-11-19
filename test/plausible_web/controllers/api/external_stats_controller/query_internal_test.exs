defmodule PlausibleWeb.Api.ExternalStatsController.QueryInternalTest do
  @moduledoc """
  A module for testing API v2 with the `:internal` schema.
  """

  use PlausibleWeb.ConnCase

  describe "comparisons" do
    setup [:create_user, :create_new_site, :create_api_key, :use_api_key, :create_site_import]

    test "aggregates a single metric", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2021-01-07", "2021-01-13"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })

      assert json_response(conn, 200)["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [1],
                 "comparison" => %{"change" => [-67], "dimensions" => [], "metrics" => [3]}
               }
             ]
    end

    test "timeseries comparison", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-06 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-08 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2021-01-07", "2021-01-13"],
          "dimensions" => ["time:day"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })

      assert json_response(conn, 200)["results"] == [
               %{
                 "dimensions" => ["2021-01-07"],
                 "metrics" => [1],
                 "comparison" => %{
                   "dimensions" => ["2020-12-31"],
                   "metrics" => [0],
                   "change" => [100]
                 }
               },
               %{
                 "dimensions" => ["2021-01-08"],
                 "metrics" => [1],
                 "comparison" => %{
                   "dimensions" => ["2021-01-01"],
                   "metrics" => [2],
                   "change" => [-50]
                 }
               },
               %{
                 "dimensions" => ["2021-01-09"],
                 "metrics" => [0],
                 "comparison" => %{
                   "dimensions" => ["2021-01-02"],
                   "metrics" => [0],
                   "change" => [0]
                 }
               },
               %{
                 "dimensions" => ["2021-01-10"],
                 "metrics" => [0],
                 "comparison" => %{
                   "dimensions" => ["2021-01-03"],
                   "metrics" => [0],
                   "change" => [0]
                 }
               },
               %{
                 "dimensions" => ["2021-01-11"],
                 "metrics" => [0],
                 "comparison" => %{
                   "dimensions" => ["2021-01-04"],
                   "metrics" => [0],
                   "change" => [0]
                 }
               },
               %{
                 "dimensions" => ["2021-01-12"],
                 "metrics" => [0],
                 "comparison" => %{
                   "dimensions" => ["2021-01-05"],
                   "metrics" => [0],
                   "change" => [0]
                 }
               },
               %{
                 "dimensions" => ["2021-01-13"],
                 "metrics" => [0],
                 "comparison" => %{
                   "dimensions" => ["2021-01-06"],
                   "metrics" => [1],
                   "change" => [-100]
                 }
               }
             ]
    end

    test "dimensional comparison with low limit", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "percentage"],
          "date_range" => ["2021-01-07", "2021-01-13"],
          "dimensions" => ["visit:browser"],
          "include" => %{
            "comparisons" => %{"mode" => "previous_period"}
          },
          "pagination" => %{"limit" => 2}
        })

      assert json_response(conn, 200)["results"] == [
               %{
                 "dimensions" => ["Chrome"],
                 "metrics" => [2, 66.7],
                 "comparison" => %{
                   "dimensions" => ["Chrome"],
                   "metrics" => [1, 12.5],
                   "change" => [100, 434]
                 }
               },
               %{
                 "dimensions" => ["Firefox"],
                 "metrics" => [1, 33.3],
                 "comparison" => %{
                   "dimensions" => ["Firefox"],
                   "metrics" => [4, 50.0],
                   "change" => [-75, -33]
                 }
               }
             ]
    end

    test "dimensional comparison with imported data", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00]),
        build(:imported_browsers,
          date: ~D[2021-01-01],
          browser: "Firefox",
          browser_version: "121",
          visitors: 50
        ),
        build(:imported_browsers,
          date: ~D[2021-01-01],
          browser: "Chrome",
          browser_version: "99",
          visitors: 39
        ),
        build(:imported_browsers,
          date: ~D[2021-01-01],
          browser: "Safari",
          browser_version: "99",
          visitors: 10
        ),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 99)
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "percentage"],
          "date_range" => ["2021-01-07", "2021-01-13"],
          "dimensions" => ["visit:browser"],
          "include" => %{
            "imports" => true,
            "comparisons" => %{"mode" => "previous_period"}
          },
          "pagination" => %{"limit" => 2}
        })

      assert json_response(conn, 200)["results"] == [
               %{
                 "dimensions" => ["Chrome"],
                 "metrics" => [2, 66.7],
                 "comparison" => %{
                   "dimensions" => ["Chrome"],
                   "metrics" => [40, 40.0],
                   "change" => [-95, 67]
                 }
               },
               %{
                 "dimensions" => ["Firefox"],
                 "metrics" => [1, 33.3],
                 "comparison" => %{
                   "dimensions" => ["Firefox"],
                   "metrics" => [50, 50.0],
                   "change" => [-98, -33]
                 }
               }
             ]
    end
  end

  describe "scroll_depth" do
    setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

    test "can query scroll_depth metric with a page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 40),
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:10]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:20], scroll_depth: 60),
        build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 456, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 80)
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "filters" => [["is", "event:page", ["/"]]],
          "date_range" => "all",
          "metrics" => ["scroll_depth"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [70], "dimensions" => []}
             ]
    end

    test "scroll depth is 0 when no pageleave data in range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "filters" => [["is", "event:page", ["/"]]],
          "date_range" => "all",
          "metrics" => ["visitors", "scroll_depth"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [1, 0], "dimensions" => []}
             ]
    end

    test "scroll depth is 0 when no data at all in range", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "filters" => [["is", "event:page", ["/"]]],
          "date_range" => "all",
          "metrics" => ["scroll_depth"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [0], "dimensions" => []}
             ]
    end

    test "scroll_depth metric in a time:day breakdown", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, timestamp: t0),
        build(:pageleave, user_id: 12, timestamp: t1, scroll_depth: 20),
        build(:pageview, user_id: 34, timestamp: t0),
        build(:pageleave, user_id: 34, timestamp: t1, scroll_depth: 17),
        build(:pageview, user_id: 34, timestamp: t2),
        build(:pageleave, user_id: 34, timestamp: t3, scroll_depth: 60),
        build(:pageview, user_id: 56, timestamp: NaiveDateTime.add(t0, 1, :day)),
        build(:pageleave,
          user_id: 56,
          timestamp: NaiveDateTime.add(t1, 1, :day),
          scroll_depth: 20
        )
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["scroll_depth"],
          "date_range" => "all",
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:page", ["/"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-01-01"], "metrics" => [40]},
               %{"dimensions" => ["2020-01-02"], "metrics" => [20]}
             ]
    end

    test "breakdown by event:page with scroll_depth metric", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 12, pathname: "/blog", timestamp: t1, scroll_depth: 20),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: t1),
        build(:pageleave, user_id: 12, pathname: "/another", timestamp: t2, scroll_depth: 24),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 34, pathname: "/blog", timestamp: t1, scroll_depth: 17),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: t1),
        build(:pageleave, user_id: 34, pathname: "/another", timestamp: t2, scroll_depth: 26),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t2),
        build(:pageleave, user_id: 34, pathname: "/blog", timestamp: t3, scroll_depth: 60),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: t0),
        build(:pageleave, user_id: 56, pathname: "/blog", timestamp: t1, scroll_depth: 100)
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["scroll_depth"],
          "date_range" => "all",
          "dimensions" => ["event:page"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [60]},
               %{"dimensions" => ["/another"], "metrics" => [25]}
             ]
    end

    test "breakdown by event:page + visit:source with scroll_depth metric", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00]
        ),
        build(:pageleave,
          referrer_source: "Google",
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(1, :minute),
          scroll_depth: 20
        ),
        build(:pageview,
          referrer_source: "Google",
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00]
        ),
        build(:pageleave,
          referrer_source: "Google",
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(1, :minute),
          scroll_depth: 17
        ),
        build(:pageview,
          referrer_source: "Google",
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(2, :minute)
        ),
        build(:pageleave,
          referrer_source: "Google",
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(3, :minute),
          scroll_depth: 60
        ),
        build(:pageview,
          referrer_source: "Twitter",
          user_id: 56,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00]
        ),
        build(:pageleave,
          referrer_source: "Twitter",
          user_id: 56,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(1, :minute),
          scroll_depth: 20
        ),
        build(:pageview,
          referrer_source: "Twitter",
          user_id: 56,
          pathname: "/another",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(1, :minute)
        ),
        build(:pageleave,
          referrer_source: "Twitter",
          user_id: 56,
          pathname: "/another",
          timestamp: ~N[2020-01-01 00:00:00] |> NaiveDateTime.add(2, :minute),
          scroll_depth: 24
        )
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["scroll_depth"],
          "date_range" => "all",
          "dimensions" => ["event:page", "visit:source"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/blog", "Google"], "metrics" => [40]},
               %{"dimensions" => ["/another", "Twitter"], "metrics" => [24]},
               %{"dimensions" => ["/blog", "Twitter"], "metrics" => [20]}
             ]
    end

    test "breakdown by event:page + time:day with scroll_depth metric", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageleave,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:01:00],
          scroll_depth: 20
        ),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: ~N[2020-01-01 00:01:00]),
        build(:pageleave,
          user_id: 12,
          pathname: "/another",
          timestamp: ~N[2020-01-01 00:02:00],
          scroll_depth: 24
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageleave,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:01:00],
          scroll_depth: 17
        ),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: ~N[2020-01-01 00:01:00]),
        build(:pageleave,
          user_id: 34,
          pathname: "/another",
          timestamp: ~N[2020-01-01 00:02:00],
          scroll_depth: 26
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: ~N[2020-01-01 00:02:00]),
        build(:pageleave,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:03:00],
          scroll_depth: 60
        ),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: ~N[2020-01-02 00:00:00]),
        build(:pageleave,
          user_id: 56,
          pathname: "/blog",
          timestamp: ~N[2020-01-02 00:01:00],
          scroll_depth: 20
        ),
        build(:pageview, user_id: 56, pathname: "/another", timestamp: ~N[2020-01-02 00:01:00]),
        build(:pageleave,
          user_id: 56,
          pathname: "/another",
          timestamp: ~N[2020-01-02 00:02:00],
          scroll_depth: 24
        )
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["scroll_depth"],
          "date_range" => "all",
          "dimensions" => ["event:page", "time:day"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/blog", "2020-01-01"], "metrics" => [40]},
               %{"dimensions" => ["/another", "2020-01-01"], "metrics" => [25]},
               %{"dimensions" => ["/another", "2020-01-02"], "metrics" => [24]},
               %{"dimensions" => ["/blog", "2020-01-02"], "metrics" => [20]}
             ]
    end
  end
end
