defmodule PlausibleWeb.Api.StatsController.TopStatsTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  defp do_query_success(conn, site, params) do
    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "default" do
    setup [:create_user, :log_in, :create_site]

    test "returns all top stats metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 3421, timestamp: ~N[2020-12-31 23:30:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-31 23:59:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2020-12-31 23:59:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 617_235, timestamp: ~N[2021-01-03 00:00:00])
      ])

      params = %{
        "date_range" => "day",
        "relative_date" => "2021-01-01",
        "filters" => [],
        "metrics" => [
          "visitors",
          "visits",
          "pageviews",
          "views_per_visit",
          "bounce_rate",
          "visit_duration"
        ]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, 2, 2, 2.0, 0, 120]}]
    end

    test "returns all page-filtered top stats metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 199_000
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 1_000
        )
      ])

      params = %{
        "date_range" => "day",
        "relative_date" => "2021-01-01",
        "filters" => [["is", "event:page", ["/pageA"]]],
        "metrics" => [
          "visitors",
          "visits",
          "pageviews",
          "bounce_rate",
          "scroll_depth",
          "time_on_page"
        ]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{"dimensions" => [], "metrics" => [2, 2, 2, 50, 0, 200]}
             ]
    end

    test "calculates time on page when filtered for multiple pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 199_000
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 20_000
        ),
        build(:pageview,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:engagement,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:17:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:00],
          engagement_time: 1_000
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/pageA", "/pageB"]]],
        "metrics" => ["time_on_page"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [220]}]
    end

    test "calculates time on page when filtered for multiple negated pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 199_000
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 20_000
        ),
        build(:pageview,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:engagement,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:17:00]
        ),
        build(:engagement,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:00],
          engagement_time: 1_000
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is_not", "event:page", ["/pageA", "/pageC"]]],
        "metrics" => ["time_on_page"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [20]}]
    end

    test "calculates time_on_page when filtered for multiple contains pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 100_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00],
          engagement_time: 20_000
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:engagement,
          pathname: "/articles/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:00],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:17:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:30],
          engagement_time: 3_000
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["contains", "event:page", ["/blog/", "/articles/"]]],
        "metrics" => ["time_on_page"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [130]}]
    end

    test "calculates time on page when filtered for multiple negated contains pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 100_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00],
          engagement_time: 20_000
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:engagement,
          pathname: "/articles/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:00],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:17:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:17:30],
          engagement_time: 3_000
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["contains_not", "event:page", ["/blog/", "/articles/"]]],
        "metrics" => ["time_on_page"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [23]}]
    end

    test "bounce_rate is 0 when the page in filter was never a landing page", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/A", user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["bounce_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [0]}]
    end

    test "time_on_page is 0 when it can't be calculated", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/")
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["time_on_page"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [0]}]
    end
  end

  describe "imported data" do
    setup [
      :create_user,
      :log_in,
      :create_site,
      :create_legacy_site_import
    ]

    test "returns scroll depth warning", %{conn: conn, site: site} do
      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["visitors", "scroll_depth"],
        "include" => %{"imports" => true}
      }

      assert %{"results" => results, "meta" => meta} =
               do_query_success(conn, site, params)

      assert results == [%{"dimensions" => [], "metrics" => [0, nil]}]
      assert meta["metric_warnings"]["scroll_depth"]["code"] == "no_imported_scroll_depth"
    end

    test "returns divisible metrics as 0 when no stats exist", %{
      site: site,
      conn: conn
    } do
      params = %{
        "date_range" => "all",
        "filters" => [],
        "metrics" => ["bounce_rate", "views_per_visit", "visit_duration"],
        "include" => %{"imports" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [0, 0, 0]}]
    end

    test "merges imported data into all top stat metrics", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:imported_visitors, date: ~D[2021-01-01])
      ])

      params = %{
        "date_range" => "all",
        "filters" => [],
        "metrics" => [
          "visitors",
          "visits",
          "pageviews",
          "views_per_visit",
          "bounce_rate",
          "visit_duration"
        ],
        "include" => %{"imports" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{"dimensions" => [], "metrics" => [3, 3, 4, 1.33, 33, 303]}
             ]
    end

    test ":member filter on country", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:imported_locations,
          country: "EE",
          date: ~D[2021-01-01],
          visitors: 1,
          visits: 3,
          pageviews: 34,
          bounces: 0,
          visit_duration: 420
        ),
        build(:imported_locations,
          country: "FR",
          date: ~D[2021-01-01],
          visitors: 3,
          visits: 7,
          pageviews: 65,
          bounces: 1,
          visit_duration: 300
        ),
        build(:imported_locations, country: "US", date: ~D[2021-01-01], visitors: 999)
      ])

      params = %{
        "date_range" => ["2021-01-01", "2021-01-01"],
        "filters" => [["is", "visit:country", ["EE", "FR"]]],
        "metrics" => [
          "visitors",
          "visits",
          "pageviews",
          "views_per_visit",
          "bounce_rate",
          "visit_duration"
        ],
        "include" => %{"imports" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{"dimensions" => [], "metrics" => [5, 11, 101, 9.18, 9, 71]}
             ]
    end

    test ":is filter on page returns visitors, visits, pageviews bounce_rate, time_on_page and scroll_depth",
         %{
           conn: conn,
           site: site
         } do
      site_import =
        insert(:site_import, site: site, start_date: ~D[2021-01-01], has_scroll_depth: true)

      populate_stats(site, site_import.id, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          total_time_on_page: 120,
          total_time_on_page_visits: 3,
          visitors: 1,
          visits: 3,
          pageviews: 34
        ),
        build(:imported_pages, page: "/ignored", date: ~D[2021-01-01], visitors: 999)
      ])

      params = %{
        "date_range" => ["2021-01-01", "2021-01-01"],
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => [
          "visitors",
          "visits",
          "pageviews",
          "bounce_rate",
          "time_on_page",
          "scroll_depth"
        ],
        "include" => %{"imports" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{"dimensions" => [], "metrics" => [2, 4, 36, 0, 40, nil]}
             ]
    end
  end

  describe "imports_meta" do
    setup [:create_user, :log_in, :create_site]

    setup context do
      insert(:site_import,
        site: context.site,
        start_date: ~D[2021-03-01],
        end_date: ~D[2021-03-31]
      )

      context
    end

    test "in realtime", %{conn: conn, site: site} do
      params = %{
        "date_range" => ["2021-01-01", "2021-01-01"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == "out_of_range"
      assert meta["imports_included"] == false
    end

    test "when the site has no imported data", %{conn: conn, site: site} do
      Plausible.Imported.delete_imports_for_site(site)

      params = %{
        "date_range" => ["2021-01-01", "2021-01-01"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == "no_imported_data"
      assert meta["imports_included"] == false
    end

    test "when imported data does not exist in the queried period", %{conn: conn, site: site} do
      params = %{
        "date_range" => ["2022-05-05", "2022-05-05"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == "out_of_range"
      assert meta["imports_included"] == false
    end

    test "when imported data is requested, in range, and can be included", %{
      conn: conn,
      site: site
    } do
      params = %{
        "date_range" => ["2021-03-15", "2021-03-15"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports" => true, "imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == nil
      assert meta["imports_included"] == true
    end

    test "when imported data is not requested, but in range and can be included", %{
      conn: conn,
      site: site
    } do
      params = %{
        "date_range" => ["2021-03-15", "2021-03-15"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports" => false, "imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == nil
      assert meta["imports_included"] == false
    end

    test "when imported data is requested and in range, but cannot be included", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "date_range" => ["2021-03-15", "2021-03-15"],
        "filters" => [
          ["is", "event:goal", ["Signup"]],
          ["is", "event:page", ["/register"]]
        ],
        "metrics" => ["visitors"],
        "include" => %{"imports" => true, "imports_meta" => true}
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == "unsupported_query"
      assert meta["imports_included"] == false
    end

    test "when imported data is requested and in comparison range", %{conn: conn, site: site} do
      params = %{
        "date_range" => ["2022-03-15", "2022-03-15"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{
          "imports" => true,
          "imports_meta" => true,
          "compare" => "year_over_year"
        }
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == nil
      assert meta["imports_included"] == true
    end

    test "when imported data is not requested and in comparison range", %{conn: conn, site: site} do
      params = %{
        "date_range" => ["2022-03-15", "2022-03-15"],
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{
          "imports" => false,
          "imports_meta" => true,
          "compare" => "year_over_year"
        }
      }

      assert %{"meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_skip_reason"] == nil
      assert meta["imports_included"] == false
    end
  end

  describe "realtime" do
    setup [:create_user, :log_in, :create_site]

    test "current visitors (last 5 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minute: -10)),
        build(:pageview, timestamp: relative_time(minute: -4)),
        build(:pageview, timestamp: relative_time(minute: -1))
      ])

      params = %{
        "date_range" => "realtime",
        "filters" => [],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "visitors and pageviews (last 30 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: relative_time(minute: -45)),
        build(:pageview, user_id: @user_id, timestamp: relative_time(minute: -25)),
        build(:pageview, user_id: @user_id, timestamp: relative_time(minute: -20)),
        build(:pageview, timestamp: relative_time(minute: -1))
      ])

      params = %{
        "date_range" => "realtime_30m",
        "filters" => [],
        "metrics" => ["visitors", "pageviews"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, 3]}]
    end

    test "visitors, events, and CR with goal filter (last 30 min)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup", timestamp: relative_time(minute: -45)),
        build(:event, name: "Signup", timestamp: relative_time(minute: -25)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minute: -22)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minute: -21)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minute: -20)),
        build(:pageview, timestamp: relative_time(minute: -20))
      ])

      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "date_range" => "realtime_30m",
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["visitors", "events", "conversion_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, 4, 66.67]}]
    end
  end

  describe "filters" do
    setup [:create_user, :log_in, :create_site]

    test "returns only visitors from a country based on alpha2 code", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "EE")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["is", "visit:country", ["US"]]],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "returns scroll_depth with a page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement, user_id: 123, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 40),
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:10]),
        build(:engagement, user_id: 123, timestamp: ~N[2021-01-01 00:00:20], scroll_depth: 60),
        build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement, user_id: 456, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 80)
      ])

      params = %{
        "date_range" => "day",
        "relative_date" => "2021-01-01",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["scroll_depth"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [70]}]
    end

    test "returns scroll_depth with a page filter with imported data", %{conn: conn, site: site} do
      site_import =
        insert(:site_import, site: site, start_date: ~D[2021-01-01], has_scroll_depth: true)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement, user_id: 123, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 40),
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:10]),
        build(:engagement, user_id: 123, timestamp: ~N[2021-01-01 00:00:20], scroll_depth: 60),
        build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement, user_id: 456, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 80),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          visitors: 8,
          total_scroll_depth: 410,
          total_scroll_depth_visits: 8
        ),
        build(:imported_pages, page: "/", date: ~D[2021-01-02], visitors: 100)
      ])

      params = %{
        "date_range" => "7d",
        "relative_date" => "2021-01-07",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["visitors", "scroll_depth"],
        "include" => %{"imports" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [110, 55]}]
    end

    test "contains filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/some-blog-post"),
        build(:pageview, pathname: "/blog/post1"),
        build(:pageview, pathname: "/another/post")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["contains", "event:page", ["blog"]]],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "returns only visitors with specific screen size", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Mobile")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["is", "visit:screen", ["Desktop"]]],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "returns only visitors with specific screen size for a given hostname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop", hostname: "blog.example.com"),
        build(:pageview, screen_size: "Desktop", hostname: "example.com", user_id: @user_id),
        build(:pageview, screen_size: "Desktop", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview,
          screen_size: "Desktop",
          hostname: "blog.example.com",
          user_id: @user_id + 1
        ),
        build(:pageview, screen_size: "Desktop", hostname: "example.com", user_id: @user_id + 1),
        build(:pageview, screen_size: "Mobile", hostname: "blog.example.com")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [
          ["is", "visit:screen", ["Desktop"]],
          ["is", "event:hostname", ["blog.example.com"]]
        ],
        "metrics" => ["visitors", "visits"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [3, 3]}]
    end

    test "returns only visitors with specific browser", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Safari")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["is", "visit:browser", ["Chrome"]]],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "returns only visitors with specific operating system", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Windows")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["is", "visit:os", ["Mac"]]],
        "metrics" => ["visitors"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "returns number of visits from one specific referral source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 05:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00])
      ])

      params = %{
        "date_range" => "day",
        "relative_date" => "2021-01-01",
        "filters" => [["is", "visit:source", ["Google"]]],
        "metrics" => ["visits"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end

    test "hostname exact filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview,
          pathname: "/blog/post1",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["is", "event:hostname", ["example.com"]]],
        "metrics" => ["visitors", "pageviews"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, 2]}]
    end

    test "hostname contains filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview,
          pathname: "/blog/post1",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/blog/post2",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com"),
        build(:pageview, pathname: "/blog/post2", hostname: "about.example.com")
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["contains", "event:hostname", ["example.com"]]],
        "metrics" => ["visitors", "pageviews"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [4, 6]}]
    end

    test "hostname contains subdomain filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview,
          pathname: "/blog/post1",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/blog/post2",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview, pathname: "/blog/post3", hostname: "blog.example.com"),
        build(:pageview,
          pathname: "/blog/post2",
          hostname: "blog.example.com",
          user_id: 100_002_378_237
        )
      ])

      params = %{
        "date_range" => "month",
        "filters" => [["contains", "event:hostname", [".example.com"]]],
        "metrics" => ["visitors", "pageviews"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [3, 4]}]
    end
  end

  describe "goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique and total conversions and conversion rate", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, user_id: 1, name: "Signup"),
        build(:event, user_id: 1, name: "Signup"),
        build(:event, user_id: 2, name: "Signup")
      ])

      params = %{
        "date_range" => "day",
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["visitors", "events", "conversion_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, 3, 50.0]}]
    end

    @tag :ee_only
    test "returns average and total when filtering by a revenue goal", %{conn: conn, site: site} do
      insert(:goal,
        site: site,
        event_name: "Payment",
        currency: "USD",
        display_name: "PaymentUSD"
      )

      insert(:goal,
        site: site,
        event_name: "AddToCart",
        currency: "EUR",
        display_name: "AddToCartEUR"
      )

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["PaymentUSD"]]],
        "metrics" => ["average_revenue", "total_revenue"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [
                   %{
                     "long" => "$1,659.50",
                     "short" => "$1.7K",
                     "value" => 1659.5,
                     "currency" => "USD"
                   },
                   %{
                     "long" => "$3,319.00",
                     "short" => "$3.3K",
                     "value" => 3319.0,
                     "currency" => "USD"
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "returns average and total when filtering by many revenue goals with same currency", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "Payment2", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment2",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment2",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Payment", "Payment2"]]],
        "metrics" => ["average_revenue", "total_revenue"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [
                   %{
                     "long" => "$1,659.50",
                     "short" => "$1.7K",
                     "value" => 1659.5,
                     "currency" => "USD"
                   },
                   %{
                     "long" => "$6,638.00",
                     "short" => "$6.6K",
                     "value" => 6638.0,
                     "currency" => "USD"
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "does not return average and total when filtering by many revenue goals with different currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Payment", "AddToCart"]]],
        "metrics" => ["visitors", "events", "conversion_rate", "total_revenue", "average_revenue"]
      }

      %{"results" => results, "query" => query} = do_query_success(conn, site, params)

      assert query["metrics"] == ["visitors", "events", "conversion_rate"]
      assert results == [%{"dimensions" => [], "metrics" => [4, 4, 100.0]}]
    end

    @tag :ee_only
    test "returns average and total revenue when filtering by many goals some which don't have currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Signup"),
        build(:event, name: "Signup")
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Payment", "Signup"]]],
        "metrics" => ["average_revenue", "total_revenue"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [
                   %{
                     "long" => "$1,000.00",
                     "short" => "$1.0K",
                     "value" => 1000.0,
                     "currency" => "USD"
                   },
                   %{
                     "long" => "$2,000.00",
                     "short" => "$2.0K",
                     "value" => 2000.0,
                     "currency" => "USD"
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "returns average and total revenue when no conversions",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Payment", "Signup"]]],
        "metrics" => ["average_revenue", "total_revenue"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [
                   %{"long" => "$0.00", "short" => "$0.0", "value" => 0.0, "currency" => "USD"},
                   %{"long" => "$0.00", "short" => "$0.0", "value" => 0.0, "currency" => "USD"}
                 ]
               }
             ]
    end

    @tag :ee_only
    test "does not return average and total revenue when filtering non-currency goal",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", display_name: "PaymentWithoutCurrency")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["PaymentWithoutCurrency"]]],
        "metrics" => ["visitors", "events", "conversion_rate", "total_revenue", "average_revenue"]
      }

      %{"results" => results, "query" => query} = do_query_success(conn, site, params)

      assert query["metrics"] == ["visitors", "events", "conversion_rate"]
      assert results == [%{"dimensions" => [], "metrics" => [2, 2, 100.0]}]
    end

    test "does not return average and total when site owner is on a growth plan",
         %{conn: conn, site: site, user: user} do
      subscribe_to_growth_plan(user)
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Payment"]]],
        "metrics" => ["visitors", "events", "conversion_rate", "total_revenue", "average_revenue"]
      }

      %{"results" => results, "query" => query} = do_query_success(conn, site, params)

      assert query["metrics"] == ["visitors", "events", "conversion_rate"]
      assert results == [%{"dimensions" => [], "metrics" => [1, 1, 100.0]}]
    end

    test "page scroll goal filter", %{conn: conn, site: site} do
      insert(:goal, site: site, page_path: "/blog", scroll_threshold: 50)

      populate_stats(site, [
        build(:pageview, user_id: 123, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 123,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 60
        ),
        build(:pageview, user_id: 456, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 456,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 40
        )
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Visit /blog"]]],
        "metrics" => ["visitors", "events", "conversion_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [1, nil, 50.0]}]
    end

    test "goal is page scroll OR custom event", %{conn: conn, site: site} do
      insert(:goal, site: site, page_path: "/blog", scroll_threshold: 50)
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 123, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event,
          user_id: 123,
          pathname: "/blog",
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:05]
        ),
        build(:engagement,
          user_id: 123,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 60
        ),
        build(:pageview, user_id: 456, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 456,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 40
        ),
        build(:pageview, user_id: 789, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 789,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 100
        ),
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00])
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Visit /blog", "Signup"]]],
        "metrics" => ["visitors", "events", "conversion_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [3, nil, 60.0]}]
    end

    test "goal is page scroll OR pageview goal", %{conn: conn, site: site} do
      insert(:goal,
        site: site,
        page_path: "/blog**",
        scroll_threshold: 50,
        display_name: "Scroll 50 /blog**"
      )

      insert(:goal, site: site, page_path: "/blog")

      populate_stats(site, [
        build(:pageview, user_id: 123, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 123,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 60
        ),
        build(:pageview, user_id: 456, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 456,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 40
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00])
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Visit /blog", "Scroll 50 /blog**"]]],
        "metrics" => ["visitors", "events", "conversion_rate"]
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [%{"dimensions" => [], "metrics" => [2, nil, 66.67]}]
    end
  end

  describe "comparisons" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns comparison data when mode is custom", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-20 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 10:00:00])
      ])

      params = %{
        "date_range" => "day",
        "relative_date" => "2021-01-01",
        "filters" => [],
        "metrics" => ["visits"],
        "include" => %{"compare" => ["2020-01-01", "2020-01-20"]}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [3],
                 "comparison" => %{"dimensions" => [], "metrics" => [3], "change" => [0]}
               }
             ]
    end

    test "returns source query and comparison query date range", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-20 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 10:00:00])
      ])

      params = %{
        "date_range" => "month",
        "relative_date" => "2021-01-01",
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"compare" => "previous_period"}
      }

      assert %{"query" => query} = do_query_success(conn, site, params)

      assert query["date_range"] == ["2021-01-01T00:00:00Z", "2021-01-31T23:59:59Z"]
      assert query["comparison_date_range"] == ["2020-12-01T00:00:00Z", "2020-12-31T23:59:59Z"]
    end

    test "compares native and imported data", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      params = %{
        "date_range" => "month",
        "relative_date" => "2021-01-01",
        "filters" => [],
        "metrics" => ["visits"],
        "include" => %{"imports" => true, "imports_meta" => true, "compare" => "year_over_year"}
      }

      %{"results" => results, "meta" => meta} = do_query_success(conn, site, params)

      assert meta["imports_included"] == true

      assert results == [
               %{
                 "dimensions" => [],
                 "metrics" => [4],
                 "comparison" => %{"dimensions" => [], "metrics" => [2], "change" => [100]}
               }
             ]
    end

    test "does not compare imported data when include.imports is false", %{
      site: site,
      conn: conn
    } do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      params = %{
        "date_range" => "month",
        "relative_date" => "2021-01-01",
        "filters" => [],
        "metrics" => ["visits"],
        "include" => %{"imports" => false, "compare" => "year_over_year"}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [4],
                 "comparison" => %{"dimensions" => [], "metrics" => [0], "change" => [100]}
               }
             ]
    end

    test "compares conversion rates", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, timestamp: ~N[2023-01-03T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-02T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-02T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-02T00:00:00])
      ])

      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "date_range" => "day",
        "relative_date" => "2023-01-03",
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["conversion_rate"],
        "include" => %{"compare" => "previous_period"}
      }

      response = do_query_success(conn, site, params)

      assert response["results"] == [
               %{
                 "dimensions" => [],
                 "metrics" => [33.33],
                 "comparison" => %{"dimensions" => [], "metrics" => [66.67], "change" => [-33.3]}
               }
             ]
    end
  end
end
