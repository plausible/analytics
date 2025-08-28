defmodule PlausibleWeb.Api.ExternalStatsController.QuerySpecialMetricsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  test "returns conversion_rate in a goal filtered custom prop breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/2", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/3", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Marko"]),
      build(:pageview,
        pathname: "/blog/2",
        "meta.key": ["author"],
        "meta.value": ["Marko"],
        user_id: 1
      ),
      build(:pageview,
        pathname: "/blog/3",
        "meta.key": ["author"],
        "meta.value": ["Marko"],
        user_id: 1
      ),
      build(:pageview, pathname: "/blog"),
      build(:pageview, "meta.key": ["author"], "meta.value": ["Marko"]),
      build(:pageview)
    ])

    insert(:goal, %{site: site, page_path: "/blog**"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Visit /blog**"]]],
        "metrics" => ["visitors", "events", "conversion_rate"],
        "dimensions" => ["event:props:author"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Uku"], "metrics" => [3, 3, 37.5]},
             %{"dimensions" => ["Marko"], "metrics" => [2, 3, 25.0]},
             %{"dimensions" => ["(none)"], "metrics" => [1, 1, 12.5]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered custom prop breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview)
    ])

    insert(:goal, %{site: site, page_path: "/blog**"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["event:props:author"],
        "filters" => [["is", "event:goal", ["Visit /blog**"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Uku"], "metrics" => [50]}
           ]
  end

  test "returns conversion_rate in a goal filtered event:page breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, pathname: "/en/register", name: "pageview"),
      build(:event, pathname: "/en/register", name: "Signup"),
      build(:event, pathname: "/en/register", name: "Signup"),
      build(:event, pathname: "/it/register", name: "Signup", user_id: 1),
      build(:event, pathname: "/it/register", name: "Signup", user_id: 1),
      build(:event, pathname: "/it/register", name: "pageview")
    ])

    insert(:goal, %{site: site, event_name: "Signup"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["visitors", "events", "group_conversion_rate"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/en/register"], "metrics" => [2, 2, 66.67]},
             %{"dimensions" => ["/it/register"], "metrics" => [1, 2, 50.0]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered event:page breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, pathname: "/en/register", name: "pageview"),
      build(:event, pathname: "/en/register", name: "Signup")
    ])

    insert(:goal, %{site: site, event_name: "Signup"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["group_conversion_rate"],
        "dimensions" => ["event:page"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/en/register"], "metrics" => [50.0]}
           ]
  end

  test "returns conversion_rate in a multi-goal filtered visit:screen_size breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, screen_size: "Mobile", name: "pageview"),
      build(:event, screen_size: "Mobile", name: "AddToCart"),
      build(:event, screen_size: "Mobile", name: "AddToCart"),
      build(:event, screen_size: "Desktop", name: "AddToCart", user_id: 1),
      build(:event, screen_size: "Desktop", name: "Purchase", user_id: 1),
      build(:event, screen_size: "Desktop", name: "pageview")
    ])

    # Make sure that revenue goals are treated the same
    # way as regular custom event goals
    insert(:goal, %{site: site, event_name: "Purchase", currency: :EUR})
    insert(:goal, %{site: site, event_name: "AddToCart"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events", "group_conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"],
        "filters" => [["is", "event:goal", ["AddToCart", "Purchase"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Mobile"], "metrics" => [2, 2, 66.67]},
             %{"dimensions" => ["Desktop"], "metrics" => [1, 2, 50]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered visit:screen_size breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, screen_size: "Mobile", name: "pageview"),
      build(:event, screen_size: "Mobile", name: "AddToCart")
    ])

    insert(:goal, %{site: site, event_name: "AddToCart"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"],
        "filters" => [["is", "event:goal", ["AddToCart"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Mobile"], "metrics" => [50]}
           ]
  end

  test "can break down by visit:device with only percentage metric", %{conn: conn, site: site} do
    site_import = insert(:site_import, site: site)

    populate_stats(site, site_import.id, [
      build(:pageview, screen_size: "Mobile"),
      build(:pageview, screen_size: "Mobile"),
      build(:pageview, screen_size: "Desktop"),
      build(:imported_visitors, visitors: 5, date: ~D[2021-01-01]),
      build(:imported_devices, device: "Desktop", visitors: 5, date: ~D[2021-01-01])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["percentage"],
        "date_range" => "all",
        "dimensions" => ["visit:device"],
        "include" => %{"imports" => true}
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Desktop"], "metrics" => [75.0]},
             %{"dimensions" => ["Mobile"], "metrics" => [25.0]}
           ]
  end

  describe "exit_rate" do
    test "in visit:exit_page breakdown without filters", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/never-exit", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, user_id: 3, name: "a", pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:10:00])
      ])

      conn =
        post(
          conn,
          "/api/v2/query-internal-test",
          %{
            "site_id" => site.domain,
            "metrics" => ["exit_rate"],
            "date_range" => "all",
            "dimensions" => ["visit:exit_page"],
            "order_by" => [["exit_rate", "desc"]]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/two"], "metrics" => [100]},
               %{"dimensions" => ["/one"], "metrics" => [33.3]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:exit_page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00])
      ])

      conn =
        post(
          conn,
          "/api/v2/query-internal-test",
          %{
            "site_id" => site.domain,
            "metrics" => ["exit_rate"],
            "date_range" => "all",
            "dimensions" => ["visit:exit_page"],
            "filters" => [["is", "visit:exit_page", ["/one"]]]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/one"], "metrics" => [66.7]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:exit_page and visit:entry_page", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # Bounced sessions: Match both entry- and exit page filters
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        # Session 1: Matches both entry- and exit page filters
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        # Session 2: Does not match exit_page filter, BUT the pageview on /one still
        # gets counted towards total pageviews.
        build(:pageview, user_id: 2, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        # Session 3: Does not match entry_page filter, should be ignored
        build(:pageview, user_id: 3, pathname: "/two", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:20:00])
      ])

      conn =
        post(
          conn,
          "/api/v2/query-internal-test",
          %{
            "site_id" => site.domain,
            "metrics" => ["exit_rate"],
            "date_range" => "all",
            "dimensions" => ["visit:exit_page"],
            "filters" => [
              ["is", "visit:exit_page", ["/one"]],
              ["is", "visit:entry_page", ["/one"]]
            ]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/one"], "metrics" => [60]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:country", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one", country_code: "EE", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/one", country_code: "US", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          user_id: 1,
          pathname: "/one",
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/two",
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      conn =
        post(
          conn,
          "/api/v2/query-internal-test",
          %{
            "site_id" => site.domain,
            "metrics" => ["exit_rate"],
            "date_range" => "all",
            "filters" => [["is", "visit:country", ["EE"]]],
            "dimensions" => ["visit:exit_page"],
            "order_by" => [["exit_rate", "asc"]]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/one"], "metrics" => [50]},
               %{"dimensions" => ["/two"], "metrics" => [100.0]}
             ]
    end

    test "sorting and pagination", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:02:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:02:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:03:00])
      ])

      do_query = fn order_by, pagination ->
        conn
        |> post("/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["exit_rate"],
          "date_range" => "all",
          "dimensions" => ["visit:exit_page"],
          "order_by" => order_by,
          "pagination" => pagination
        })
        |> json_response(200)
        |> Map.get("results")
      end

      all_results_asc = do_query.([["exit_rate", "asc"]], %{"limit" => 4})
      all_results_desc = do_query.([["exit_rate", "desc"]], %{"limit" => 4})

      assert all_results_asc == Enum.reverse(all_results_desc)

      assert do_query.([["exit_rate", "desc"]], %{"limit" => 2, "offset" => 0}) == [
               %{"dimensions" => ["/one"], "metrics" => [100]},
               %{"dimensions" => ["/two"], "metrics" => [50]}
             ]

      assert do_query.([["exit_rate", "desc"]], %{"limit" => 2, "offset" => 2}) == [
               %{"dimensions" => ["/three"], "metrics" => [33.3]},
               %{"dimensions" => ["/four"], "metrics" => [25]}
             ]

      assert do_query.([["exit_rate", "asc"]], %{"limit" => 3, "offset" => 1}) == [
               %{"dimensions" => ["/three"], "metrics" => [33.3]},
               %{"dimensions" => ["/two"], "metrics" => [50]},
               %{"dimensions" => ["/one"], "metrics" => [100]}
             ]
    end

    test "with comparisons", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-09 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/three", timestamp: ~N[2021-01-09 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-09 00:10:00]),
        build(:pageview, user_id: 2, pathname: "/one", timestamp: ~N[2021-01-10 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-10 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-10 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-10 00:10:00])
      ])

      conn =
        conn
        |> Plausible.Stats.Query.Test.fix_query(%{metrics: [:exit_rate]})
        |> Plausible.Stats.Query.Test.fix_query_include(%{
          comparisons: %{mode: "previous_period"}
        })
        |> post(
          "/api/v2/query",
          %{
            "metrics" => ["visitors"],
            "site_id" => site.domain,
            "date_range" => ["2021-01-10", "2021-01-10"],
            "dimensions" => ["visit:exit_page"]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{
                 "dimensions" => ["/two"],
                 "metrics" => [100],
                 "comparison" => %{
                   "change" => [nil],
                   "dimensions" => ["/two"],
                   "metrics" => [nil]
                 }
               },
               %{
                 "dimensions" => ["/one"],
                 "metrics" => [33.3],
                 "comparison" => %{
                   "change" => [-16.7],
                   "dimensions" => ["/one"],
                   "metrics" => [50]
                 }
               }
             ]
    end

    test "with imported data", %{conn: conn, site: site} do
      site_import =
        insert(:site_import,
          site: site,
          start_date: ~D[2020-01-01],
          end_date: ~D[2020-12-31]
        )

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:10:00]),
        build(:imported_pages, page: "/one", visits: 10, pageviews: 20, date: ~D[2020-01-01]),
        build(:imported_exit_pages, exit_page: "/one", exits: 2, date: ~D[2020-01-01])
      ])

      conn =
        post(
          conn,
          "/api/v2/query-internal-test",
          %{
            "site_id" => site.domain,
            "metrics" => ["exit_rate"],
            "date_range" => "all",
            "include" => %{"imports" => true},
            "dimensions" => ["visit:exit_page"],
            "order_by" => [["exit_rate", "desc"]]
          }
        )

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/two"], "metrics" => [100]},
               %{"dimensions" => ["/one"], "metrics" => [13]}
             ]
    end
  end
end
