defmodule PlausibleWeb.Api.ExternalStatsController.QueryTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  @user_id Enum.random(1000..9999)

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  test "aggregates a single metric", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => "all"
      })

    assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
  end

  test "aggregate views_per_visit rounds to two decimal places", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all"
      })

    assert json_response(conn, 200)["results"] == [%{"metrics" => [1.67], "dimensions" => []}]
  end

  test "aggregates all metrics in a single query", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => [
          "pageviews",
          "visits",
          "views_per_visit",
          "visitors",
          "bounce_rate",
          "visit_duration"
        ]
      })

    assert json_response(conn, 200)["results"] == [
             %{"metrics" => [3, 2, 1.5, 2, 50, 750], "dimensions" => []}
           ]
  end

  describe "aggregation with filters" do
    test "can filter by source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:source", ["Google"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "does not count pageleave events towards the events metric in a simple aggregate query",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 234, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 234, timestamp: ~N[2021-01-01 00:00:01])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["events"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [1], "dimensions" => []}
             ]
    end

    test "pageleave events do not affect bounce rate and visit duration", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:03])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["bounce_rate", "visit_duration"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [100, 0], "dimensions" => []}
             ]
    end

    test "can filter by channel", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:channel", ["Organic Search"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by no source/referrer", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:source", ["Direct / None"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by referrer", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer: "https://facebook.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:referrer", ["https://facebook.com"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "contains referrer filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer: "https://a.com"),
        build(:pageview, referrer: "https://a.com"),
        build(:pageview, referrer: "https://ab.com")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains", "visit:referrer", ["a.com"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
    end

    test "can filter by utm_medium", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_medium: "social",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:utm_medium", ["social"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by utm_source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_source: "Twitter",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:utm_source", ["Twitter"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by utm_campaign", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_campaign: "profile",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:utm_campaign", ["profile"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by device type", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          screen_size: "Desktop",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:device", ["Desktop"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by browser", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          browser: "Chrome",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:browser", ["Chrome"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by browser version", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          browser: "Chrome",
          browser_version: "56",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:browser_version", ["56"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by operating system", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:os", ["Mac"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by operating system version", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system_version: "10.5",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:os_version", ["10.5"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by country", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [["is", "visit:country", ["EE"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "can filter by page", %{
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
          pathname: "/blogpost",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          pathname: "/blogpost",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [
            ["is", "event:page", ["/blogpost"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 2, 100, 750], "dimensions" => []}
             ]
    end

    test "can filter by hostname", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          hostname: "one.example.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          hostname: "example.com",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [
            ["contains", "event:hostname", ["one.example.com", "example.com"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 2, 100, 0], "dimensions" => []}
             ]
    end

    test "filtering by event:name", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "filters" => [
            ["is", "event:name", ["Signup"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 0], "dimensions" => []}]
    end

    test "filtering by a custom event goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "NotConfigured",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [
            ["is", "event:goal", ["Signup"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 3], "dimensions" => []}]
    end

    test "filtering by a revenue goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      insert(:goal, site: site, currency: :USD, event_name: "Purchase")

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [
            ["is", "event:goal", ["Purchase"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 3], "dimensions" => []}]
    end

    test "filtering by a simple pageview goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/register",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/register",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          pathname: "/register",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      insert(:goal, %{site: site, page_path: "/register"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "filters" => [
            ["is", "event:goal", ["Visit /register"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 3], "dimensions" => []}]
    end

    test "filtering by a wildcard pageview goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2", user_id: @user_id),
        build(:pageview, pathname: "/blog", user_id: @user_id),
        build(:pageview, pathname: "/")
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "filters" => [
            ["is", "event:goal", ["Visit /blog**"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 3], "dimensions" => []}]
    end

    test "filtering by multiple custom event goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Purchase", user_id: @user_id),
        build(:event, name: "Purchase", user_id: @user_id),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Purchase"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [
            ["is", "event:goal", ["Signup", "Purchase"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2, 3], "dimensions" => []}]
    end

    test "filtering by multiple mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/account/register"),
        build(:pageview, pathname: "/register", user_id: @user_id),
        build(:event, name: "Signup", user_id: @user_id),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/**register"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events", "pageviews"],
          "filters" => [
            ["is", "event:goal", ["Signup", "Visit /**register"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [2, 3, 2], "dimensions" => []}
             ]
    end

    test "combining filters", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blogpost",
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          pathname: "/blogpost",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "filters" => [
            ["is", "event:page", ["/blogpost"]],
            ["is", "visit:country", ["EE"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [1, 1, 0, 1500], "dimensions" => []}
             ]
    end

    test "contains page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains", "event:page", ["/en/"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
    end

    test "contains_not page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains_not", "event:page", ["/en/"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "contains with and/or/not filters", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/eng/page1"),
        build(:pageview, pathname: "/pl/page1"),
        build(:pageview, pathname: "/gb/page1")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            [
              "or",
              [
                [
                  "and",
                  [
                    ["contains", "event:page", ["/en"]],
                    ["not", ["contains", "event:page", ["/eng"]]]
                  ]
                ],
                ["contains", "event:page", ["/gb"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "contains and member filter combined", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1"),
        build(:pageview, pathname: "/ee/page1")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains", "event:page", ["/en/", "/pl/"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "can escape pipe character in member + contains filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post|1"),
        build(:pageview, pathname: "/otherpost|1"),
        build(:pageview, pathname: "/blog/post|2"),
        build(:pageview, pathname: "/something-else")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains", "event:page", ["post|1", "/something-else"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "`matches` operator", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/user/1234"),
        build(:pageview, pathname: "/user/789/contributions"),
        build(:pageview, pathname: "/blog/user/1234"),
        build(:pageview, pathname: "/user/ef/contributions"),
        build(:pageview, pathname: "/other/path")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["matches", "event:page", ["^/user/[0-9]+"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
    end

    test "`matches_not` operator", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/user/1234"),
        build(:pageview, pathname: "/user/789/contributions"),
        build(:pageview, pathname: "/blog/user/1234"),
        build(:pageview, pathname: "/user/ef/contributions"),
        build(:pageview, pathname: "/other/path")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["matches_not", "event:page", ["^/user/[0-9]+"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "`contains` and `contains_not` operator with custom properties", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["large-1", "ax"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-1", "bx"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-1", "ax"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-2", "bx"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-2", "cx"]
        ),
        build(:pageview,
          "meta.key": ["tier"],
          "meta.value": ["small-3"]
        ),
        build(:pageview,
          "meta.key": ["value"],
          "meta.value": ["ax"]
        ),
        build(:pageview)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["contains", "event:props:tier", ["small"]],
            ["contains_not", "event:props:value", ["b", "c"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "`matches` and `matches_not` operator with custom properties", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["large-1", "a"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-1", "b"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-1", "a"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-2", "b"]
        ),
        build(:pageview,
          "meta.key": ["tier", "value"],
          "meta.value": ["small-2", "c"]
        ),
        build(:pageview,
          "meta.key": ["tier"],
          "meta.value": ["small-3"]
        ),
        build(:pageview,
          "meta.key": ["value"],
          "meta.value": ["a"]
        ),
        build(:pageview)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "filters" => [
            ["matches", "event:props:tier", ["small.+"]],
            ["matches_not", "event:props:value", ["b|c"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "handles filtering by visit:country", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews"],
          "filters" => [["is", "visit:country", ["EE"]]]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "handles filtering by visit:country with contains", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "IT"),
        build(:pageview, country_code: "DE")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews"],
          "filters" => [["contains", "visit:country", ["E"]]]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "handles filtering by visit:city", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, city_geoname_id: 588_409),
        build(:pageview, city_geoname_id: 689_123),
        build(:pageview, city_geoname_id: 0),
        build(:pageview, city_geoname_id: 10)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews"],
          "filters" => [["is", "visit:city", [588_409, 689_123]]]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
    end
  end

  describe "timeseries" do
    test "shows hourly data for a certain date with time_labels", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, timestamp: ~N[2021-01-01 23:59:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "pageviews", "visits", "visit_duration", "bounce_rate"],
          "date_range" => ["2021-01-01", "2021-01-01"],
          "dimensions" => ["time:hour"],
          "include" => %{"time_labels" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01 00:00:00"], "metrics" => [1, 2, 1, 600, 0]},
               %{"dimensions" => ["2021-01-01 23:00:00"], "metrics" => [1, 1, 1, 0, 100]}
             ]

      assert json_response(conn, 200)["meta"]["time_labels"] == [
               "2021-01-01 00:00:00",
               "2021-01-01 01:00:00",
               "2021-01-01 02:00:00",
               "2021-01-01 03:00:00",
               "2021-01-01 04:00:00",
               "2021-01-01 05:00:00",
               "2021-01-01 06:00:00",
               "2021-01-01 07:00:00",
               "2021-01-01 08:00:00",
               "2021-01-01 09:00:00",
               "2021-01-01 10:00:00",
               "2021-01-01 11:00:00",
               "2021-01-01 12:00:00",
               "2021-01-01 13:00:00",
               "2021-01-01 14:00:00",
               "2021-01-01 15:00:00",
               "2021-01-01 16:00:00",
               "2021-01-01 17:00:00",
               "2021-01-01 18:00:00",
               "2021-01-01 19:00:00",
               "2021-01-01 20:00:00",
               "2021-01-01 21:00:00",
               "2021-01-01 22:00:00",
               "2021-01-01 23:00:00"
             ]
    end

    test "shows last 7 days of visitors with time labels", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2021-01-01", "2021-01-07"],
          "dimensions" => ["time"],
          "include" => %{"time_labels" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-07"], "metrics" => [1]}
             ]

      assert json_response(conn, 200)["meta"]["time_labels"] == [
               "2021-01-01",
               "2021-01-02",
               "2021-01-03",
               "2021-01-04",
               "2021-01-05",
               "2021-01-06",
               "2021-01-07"
             ]
    end

    test "shows weekly data with time labels", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 23:59:00]),
        build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2020-12-20", "2021-01-07"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-12-28"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [1]}
             ]

      assert json_response(conn, 200)["meta"]["time_labels"] == [
               "2020-12-20",
               "2020-12-21",
               "2020-12-28",
               "2021-01-04"
             ]
    end

    test "shows last 6 months of visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-08-13 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2020-07-01", "2021-01-31"],
          "dimensions" => ["time:month"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-08-01"], "metrics" => [1]},
               %{"dimensions" => ["2020-12-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]}
             ]
    end

    test "shows last 12 months of visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-02-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2020-01-01", "2021-01-01"],
          "dimensions" => ["time:month"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-02-01"], "metrics" => [1]},
               %{"dimensions" => ["2020-12-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]}
             ]
    end

    test "shows last 12 months of visitors with interval daily", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-02-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2020-01-01", "2021-01-07"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-02-01"], "metrics" => [1]},
               %{"dimensions" => ["2020-12-31"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]}
             ]

      assert length(json_response(conn, 200)["meta"]["time_labels"]) == 373
    end

    test "shows a custom range with daily interval", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2021-01-01", "2021-01-02"],
          "dimensions" => ["time:day"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-02"], "metrics" => [1]}
             ]
    end

    test "shows a custom range with monthly interval", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-01 00:05:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews", "visitors", "bounce_rate", "visit_duration"],
          "date_range" => ["2020-12-01", "2021-01-02"],
          "dimensions" => ["time:month"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [2, 1, 0, 300]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [2, 2, 100, 0]}
             ]
    end

    test "timeseries with explicit order_by", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-04 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-04 00:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2020-12-01", "2021-01-04"],
          "dimensions" => ["time"],
          "order_by" => [["pageviews", "desc"], ["time", "asc"]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-02"], "metrics" => [3]},
               %{"dimensions" => ["2021-01-03"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]}
             ]
    end

    test "timeseries with quarter-hour timezone", %{conn: conn, user: user} do
      # GMT+05:45
      site = new_site(timezone: "Asia/Katmandu", owner: user)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-02 05:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 05:15:00]),
        build(:pageview, timestamp: ~N[2021-01-02 05:30:00]),
        build(:pageview, timestamp: ~N[2021-01-02 05:45:00]),
        build(:pageview, timestamp: ~N[2021-01-02 06:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 06:15:00]),
        build(:pageview, timestamp: ~N[2021-01-02 06:30:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visits"],
          "date_range" => ["2021-01-02", "2021-01-02"],
          "dimensions" => ["time:hour"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-02 10:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-02 11:00:00"], "metrics" => [4]},
               %{"dimensions" => ["2021-01-02 12:00:00"], "metrics" => [2]}
             ]
    end
  end

  test "breakdown by visit:source", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        referrer_source: "",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:source"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Google"], "metrics" => [2]},
             %{"dimensions" => ["Direct / None"], "metrics" => [1]}
           ]
  end

  test "breakdown by visit:channel", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:channel"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Organic Search"], "metrics" => [2]},
             %{"dimensions" => ["Direct"], "metrics" => [1]}
           ]
  end

  test "breakdown by visit:country", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, country_code: "EE", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, country_code: "EE", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, country_code: "US", timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:country"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["EE"], "metrics" => [2]},
             %{"dimensions" => ["US"], "metrics" => [1]}
           ]
  end

  for {dimension, attr} <- [
        {"visit:utm_campaign", :utm_campaign},
        {"visit:utm_source", :utm_source},
        {"visit:utm_term", :utm_term},
        {"visit:utm_content", :utm_content}
      ] do
    test "breakdown by #{dimension} when filtered by hostname", %{conn: conn, site: site} do
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

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [["is", "event:hostname", ["one.example.com"]]],
          "dimensions" => [unquote(dimension)]
        })

      # nobody landed on one.example.com from utm_param=ad
      assert json_response(conn, 200)["results"] == []
    end
  end

  for {dimension, column, value1, value2, blank_value} <- [
        {"visit:source", :referrer_source, "Google", "Twitter", "Direct / None"},
        {"visit:referrer", :referrer, "example.com", "google.com", "Direct / None"},
        {"visit:utm_medium", :utm_medium, "Search", "social", "(not set)"},
        {"visit:utm_source", :utm_source, "Google", "Bing", "(not set)"},
        {"visit:utm_campaign", :utm_campaign, "ads", "profile", "(not set)"},
        {"visit:utm_content", :utm_content, "Content1", "blog2", "(not set)"},
        {"visit:utm_term", :utm_term, "Term1", "favicon", "(not set)"},
        {"visit:os", :operating_system, "Mac", "Windows", "(not set)"},
        {"visit:browser", :browser, "Chrome", "Safari", "(not set)"},
        {"visit:device", :screen_size, "Mobile", "Desktop", "(not set)"}
      ] do
    test "simple breakdown by #{dimension}", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, [
          {unquote(column), unquote(value1)},
          {:timestamp, ~N[2021-01-01 00:00:00]}
        ]),
        build(:pageview, [
          {unquote(column), unquote(value1)},
          {:timestamp, ~N[2021-01-01 00:25:00]}
        ]),
        build(:pageview, [
          {unquote(column), unquote(value1)},
          {:timestamp, ~N[2021-01-01 00:55:00]}
        ]),
        build(:pageview, [
          {unquote(column), unquote(value2)},
          {:timestamp, ~N[2021-01-01 01:00:00]}
        ]),
        build(:pageview, [
          {unquote(column), unquote(value2)},
          {:timestamp, ~N[2021-01-01 01:25:00]}
        ]),
        build(:pageview, [
          {unquote(column), ""},
          {:timestamp, ~N[2021-01-01 00:00:00]}
        ])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "percentage"],
          "date_range" => ["2021-01-01", "2021-01-01"],
          "dimensions" => [unquote(dimension)]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => [unquote(value1)], "metrics" => [3, 50]},
               %{"dimensions" => [unquote(value2)], "metrics" => [2, 33.3]},
               %{"dimensions" => [unquote(blank_value)], "metrics" => [1, 16.7]}
             ]
    end
  end

  test "breakdown by visit:os and visit:os_version", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, operating_system: "Mac", operating_system_version: "14"),
      build(:pageview, operating_system: "Mac", operating_system_version: "14"),
      build(:pageview, operating_system: "Mac", operating_system_version: "14"),
      build(:pageview, operating_system_version: "14"),
      build(:pageview,
        operating_system: "Windows",
        operating_system_version: "11"
      ),
      build(:pageview,
        operating_system: "Windows",
        operating_system_version: "11"
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:os", "visit:os_version"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Mac", "14"], "metrics" => [3]},
             %{"dimensions" => ["Windows", "11"], "metrics" => [2]},
             %{"dimensions" => ["(not set)", "14"], "metrics" => [1]}
           ]
  end

  test "breakdown by visit:browser and visit:browser_version", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, browser: "Chrome", browser_version: "14"),
      build(:pageview, browser: "Chrome", browser_version: "14"),
      build(:pageview, browser: "Chrome", browser_version: "14"),
      build(:pageview, browser_version: "14"),
      build(:pageview,
        browser: "Firefox",
        browser_version: "11"
      ),
      build(:pageview,
        browser: "Firefox",
        browser_version: "11"
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser", "visit:browser_version"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Chrome", "14"], "metrics" => [3]},
             %{"dimensions" => ["Firefox", "11"], "metrics" => [2]},
             %{"dimensions" => ["(not set)", "14"], "metrics" => [1]}
           ]
  end

  test "explicit order_by", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, operating_system: "Windows", browser: "Chrome"),
      build(:pageview, operating_system: "Windows", browser: "Firefox"),
      build(:pageview, operating_system: "Linux", browser: "Firefox"),
      build(:pageview, operating_system: "Linux", browser: "Firefox"),
      build(:pageview, operating_system: "Mac", browser: "Chrome")
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:os", "visit:browser"],
        "order_by" => [["visitors", "asc"], ["visit:browser", "desc"], ["visit:os", "asc"]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Windows", "Firefox"], "metrics" => [1]},
             %{"dimensions" => ["Mac", "Chrome"], "metrics" => [1]},
             %{"dimensions" => ["Windows", "Chrome"], "metrics" => [1]},
             %{"dimensions" => ["Linux", "Firefox"], "metrics" => [2]}
           ]
  end

  test "breakdown by event:page", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:page"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/"], "metrics" => [2]},
             %{"dimensions" => ["/plausible.io"], "metrics" => [1]}
           ]
  end

  test "attempting to breakdown by event:hostname returns an error", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, hostname: "a.example.com"),
      build(:pageview, hostname: "a.example.com"),
      build(:pageview, hostname: "a.example.com"),
      build(:pageview, hostname: "b.example.com")
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["pageviews"],
        "dimensions" => ["event:hostname"]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["a.example.com"], "metrics" => [3]},
             %{"dimensions" => ["b.example.com"], "metrics" => [1]}
           ]
  end

  describe "custom events" do
    test "can breakdown by event:name", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["Signup"], "metrics" => [2]},
               %{"dimensions" => ["pageview"], "metrics" => [1]}
             ]
    end

    test "can breakdown by event:name with visitors and events metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/non-existing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "404",
          pathname: "/non-existing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/non-existing",
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:pageview,
          pathname: "/non-existing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        build(:event,
          name: "404",
          pathname: "/non-existing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        build(:pageview,
          pathname: "/non-existing",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:03]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["pageview"], "metrics" => [2, 4]},
               %{"dimensions" => ["404"], "metrics" => [1, 2]}
             ]
    end

    test "can breakdown by event:name while filtering for something", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageB",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:name"],
          "filters" => [
            ["is", "event:page", ["/pageA"]],
            ["is", "visit:browser", ["Chrome"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["Signup"], "metrics" => [2]},
               %{"dimensions" => ["pageview"], "metrics" => [1]}
             ]
    end

    test "can breakdown by a visit:property when filtering by event:name", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["is", "event:name", ["Signup"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["Google"], "metrics" => [1]}
             ]
    end

    test "can breakdown by event:name when filtering by event:page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          pathname: "/pageA",
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:name"],
          "filters" => [
            ["contains", "event:page", ["/pageA"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["pageview"], "metrics" => [2]},
               %{"dimensions" => ["Signup"], "metrics" => [1]}
             ]
    end

    test "can breakdown by event:page when filtering by event:name", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageB",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["is", "event:name", ["Signup"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/pageA"], "metrics" => [2]},
               %{"dimensions" => ["/pageB"], "metrics" => [1]}
             ]
    end

    test "can filter event:page with a wildcard", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["contains", "event:page", ["/en/"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/en/page2"], "metrics" => [2]},
               %{"dimensions" => ["/en/page1"], "metrics" => [1]}
             ]
    end

    test "can filter event:hostname with a contains", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, hostname: "alice-m.example.com", pathname: "/a"),
        build(:pageview, hostname: "anna-m.example.com", pathname: "/a"),
        build(:pageview, hostname: "adam-m.example.com", pathname: "/a"),
        build(:pageview, hostname: "bob.example.com", pathname: "/b")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["contains", "event:hostname", ["-m.example.com"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/a"], "metrics" => [3]}
             ]
    end

    test "breakdown by custom event property", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["personal"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Some other event",
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:package"],
          "filters" => [
            ["is", "event:name", ["Purchase"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["business"], "metrics" => [2]},
               %{"dimensions" => ["personal"], "metrics" => [1]}
             ]
    end

    test "breakdown by custom event property, with pageviews metric", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["personal"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "dimensions" => ["event:props:package"]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["business"], "metrics" => [2]},
               %{"dimensions" => ["personal"], "metrics" => [1]}
             ]
    end

    test "breakdown by custom event property, with (none)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["16"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["16"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["16"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["14"],
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["14"],
          timestamp: ~N[2021-01-01 00:26:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:cost"],
          "filters" => [["is", "event:name", ["Purchase"]]]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["16"], "metrics" => [3]},
               %{"dimensions" => ["14"], "metrics" => [2]},
               %{"dimensions" => ["(none)"], "metrics" => [1]}
             ]
    end
  end

  test "event:goal filter returns 400 when goal not configured", %{conn: conn, site: site} do
    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "event:goal", ["Register"]]
        ]
      })

    assert %{"error" => msg} = json_response(conn, 400)
    assert msg =~ "The goal `Register` is not configured for this site. Find out how"
  end

  test "validates that filters are valid", %{conn: conn, site: site} do
    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "badproperty", ["bar"]]
        ]
      })

    assert %{"error" => msg} = json_response(conn, 400)
    assert msg =~ "Invalid filter"
  end

  test "event:page filter for breakdown by session props", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        pathname: "/ignore",
        browser: "Chrome",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        browser: "Chrome",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        browser: "Chrome",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        browser: "Safari",
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "event:page", ["/plausible.io"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Chrome"], "metrics" => [2]},
             %{"dimensions" => ["Safari"], "metrics" => [1]}
           ]
  end

  test "event:page filter shows sources of sessions that have visited that page", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview,
        pathname: "/",
        referrer_source: "Twitter",
        utm_medium: "Twitter",
        utm_source: "Twitter",
        utm_campaign: "Twitter",
        user_id: @user_id
      ),
      build(:pageview,
        pathname: "/plausible.io",
        user_id: @user_id
      ),
      build(:pageview,
        pathname: "/plausible.io",
        referrer_source: "Google",
        utm_medium: "Google",
        utm_source: "Google",
        utm_campaign: "Google"
      ),
      build(:pageview,
        pathname: "/plausible.io",
        referrer_source: "Google",
        utm_medium: "Google",
        utm_source: "Google",
        utm_campaign: "Google"
      )
    ])

    for dimension <- [
          "visit:source",
          "visit:utm_medium",
          "visit:utm_source",
          "visit:utm_campaign"
        ] do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => [dimension],
          "filters" => [
            ["is", "event:page", ["/plausible.io"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["Google"], "metrics" => [2]},
               %{"dimensions" => ["Twitter"], "metrics" => [1]}
             ]
    end
  end

  test "top sources for a custom goal and filtered by hostname", %{conn: conn, site: site} do
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

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:source"],
        "filters" => [
          ["is", "event:hostname", ["app.example.com"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == []
  end

  test "top sources for a custom goal and filtered by hostname (2)", %{conn: conn, site: site} do
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

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:source"],
        "filters" => [
          ["is", "event:hostname", ["app.example.com"]]
        ]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Facebook"], "metrics" => [1]}
           ]
  end

  test "event:page filter is interpreted as entry_page filter only for bounce_rate", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview,
        browser: "Chrome",
        user_id: @user_id,
        pathname: "/ignore",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Chrome",
        user_id: @user_id,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:01:00]
      ),
      build(:pageview,
        browser: "Chrome",
        user_id: 456,
        pathname: "/important-page",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Chrome",
        user_id: 456,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:01:00]
      ),
      build(:pageview,
        browser: "Chrome",
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:01:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["visitors", "bounce_rate"],
        "filters" => [["is", "event:page", ["/plausible.io", "/important-page"]]],
        "dimensions" => ["visit:browser"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Chrome"], "metrics" => [3, 50]}
           ]
  end

  test "event:goal pageview filter for breakdown by visit source", %{conn: conn, site: site} do
    insert(:goal, %{site: site, page_path: "/plausible.io"})

    populate_stats(site, [
      build(:pageview,
        referrer_source: "Bing",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        user_id: @user_id,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        user_id: @user_id,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:source"],
        "filters" => [
          ["is", "event:goal", ["Visit /plausible.io"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Google"], "metrics" => [1]}
           ]
  end

  test "event:goal custom event filter for breakdown by visit source", %{conn: conn, site: site} do
    insert(:goal, %{site: site, event_name: "Register"})

    populate_stats(site, [
      build(:pageview,
        referrer_source: "Bing",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        user_id: @user_id,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Register",
        user_id: @user_id,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:source"],
        "filters" => [
          ["is", "event:goal", ["Register"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Google"], "metrics" => [1]}
           ]
  end

  test "wildcard pageview goal filter for breakdown by event:page", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, pathname: "/en/register"),
      build(:pageview, pathname: "/en/register", user_id: @user_id),
      build(:pageview, pathname: "/en/register", user_id: @user_id),
      build(:pageview, pathname: "/123/it/register"),
      build(:pageview, pathname: "/should-not-appear")
    ])

    insert(:goal, %{site: site, page_path: "/**register"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "pageviews"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [
          ["is", "event:goal", ["Visit /**register"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["/en/register"], "metrics" => [2, 3]},
             %{"dimensions" => ["/123/it/register"], "metrics" => [1, 1]}
           ]
  end

  test "goal contains filter for goal breakdown", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:event, name: "Onboarding conversion: Step 1"),
      build(:event, name: "Onboarding conversion: Step 1"),
      build(:event, name: "Onboarding conversion: Step 2"),
      build(:event, name: "Unrelated"),
      build(:pageview, pathname: "/conversion")
    ])

    insert(:goal, site: site, event_name: "Onboarding conversion: Step 1")
    insert(:goal, site: site, event_name: "Onboarding conversion: Step 2")
    insert(:goal, site: site, event_name: "Unrelated")
    insert(:goal, site: site, page_path: "/conversion")

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:goal"],
        "filters" => [
          ["contains", "event:goal", ["conversion"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Onboarding conversion: Step 1"], "metrics" => [2]},
             %{"dimensions" => ["Onboarding conversion: Step 2"], "metrics" => [1]},
             %{"dimensions" => ["Visit /conversion"], "metrics" => [1]}
           ]
  end

  test "mixed multi-goal filter for breakdown by visit:country", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, country_code: "EE", pathname: "/en/register"),
      build(:event, country_code: "EE", name: "Signup", pathname: "/en/register"),
      build(:pageview, country_code: "US", pathname: "/123/it/register"),
      build(:pageview, country_code: "US", pathname: "/different")
    ])

    insert(:goal, %{site: site, page_path: "/**register"})
    insert(:goal, %{site: site, event_name: "Signup"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "pageviews", "events"],
        "date_range" => "all",
        "dimensions" => ["visit:country"],
        "filters" => [
          ["is", "event:goal", ["Signup", "Visit /**register"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["EE"], "metrics" => [2, 1, 2]},
             %{"dimensions" => ["US"], "metrics" => [1, 1, 1]}
           ]
  end

  test "event:goal custom event filter for breakdown by event page", %{conn: conn, site: site} do
    insert(:goal, %{site: site, event_name: "Register"})

    populate_stats(site, [
      build(:event,
        pathname: "/en/register",
        name: "Register"
      ),
      build(:event,
        pathname: "/en/register",
        name: "Register"
      ),
      build(:event,
        pathname: "/it/register",
        name: "Register"
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [
          ["is", "event:goal", ["Register"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["/en/register"], "metrics" => [2]},
             %{"dimensions" => ["/it/register"], "metrics" => [1]}
           ]
  end

  test "IN filter for event:page", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        pathname: "/ignore",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/important-page",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [
          ["is", "event:page", ["/plausible.io", "/important-page"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["/plausible.io"], "metrics" => [2]},
             %{"dimensions" => ["/important-page"], "metrics" => [1]}
           ]
  end

  test "IN filter for visit:browser", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        pathname: "/ignore",
        browser: "Firefox",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        browser: "Chrome",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        browser: "Safari",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/important-page",
        browser: "Safari",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [
          ["is", "visit:browser", ["Chrome", "Safari"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["/plausible.io"], "metrics" => [2]},
             %{"dimensions" => ["/important-page"], "metrics" => [1]}
           ]
  end

  test "IN filter for visit:entry_page", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        pathname: "/ignore",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        pathname: "/important-page",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [
          ["is", "event:page", ["/plausible.io", "/important-page"]]
        ]
      })

    results = json_response(conn, 200)["results"]

    assert length(results) == 2
    assert %{"dimensions" => ["/plausible.io"], "metrics" => [100]} in results
    assert %{"dimensions" => ["/important-page"], "metrics" => [100]} in results
  end

  test "IN filter for event:name", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:event,
        name: "Signup",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Signup",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Login",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Irrelevant",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name"],
        "filters" => [
          ["is", "event:name", ["Signup", "Login"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Signup"], "metrics" => [2]},
             %{"dimensions" => ["Login"], "metrics" => [1]}
           ]
  end

  test "IN filter for event:props:*", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser"],
        "meta.value": ["Chrome"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser"],
        "meta.value": ["Chrome"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Safari",
        "meta.key": ["browser"],
        "meta.value": ["Safari"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Firefox",
        "meta.key": ["browser"],
        "meta.value": ["Firefox"],
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "event:props:browser", ["Chrome", "Safari"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Chrome"], "metrics" => [2]},
             %{"dimensions" => ["Safari"], "metrics" => [1]}
           ]
  end

  test "Multiple event:props:* filters", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser"],
        "meta.value": ["Chrome"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser", "prop"],
        "meta.value": ["Chrome", "xyz"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Safari",
        "meta.key": ["browser", "prop"],
        "meta.value": ["Safari", "target_value"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Firefox",
        "meta.key": ["browser", "prop"],
        "meta.value": ["Firefox", "target_value"],
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "event:props:browser", ["Chrome", "Safari"]],
          ["is", "event:props:prop", ["target_value"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Safari"], "metrics" => [1]}
           ]
  end

  test "IN filter for event:props:* including (none) value", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser"],
        "meta.value": ["Chrome"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Chrome",
        "meta.key": ["browser"],
        "meta.value": ["Chrome"],
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Safari",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser: "Firefox",
        "meta.key": ["browser"],
        "meta.value": ["Firefox"],
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [["is", "event:props:browser", ["Chrome", "(none)"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Chrome"], "metrics" => [2]},
             %{"dimensions" => ["Safari"], "metrics" => [1]}
           ]
  end

  test "can use a is_not filter", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, browser: "Chrome"),
      build(:pageview, browser: "Safari"),
      build(:pageview, browser: "Safari"),
      build(:pageview, browser: "Edge")
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is_not", "visit:browser", ["Chrome"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Safari"], "metrics" => [2]},
             %{"dimensions" => ["Edge"], "metrics" => [1]}
           ]
  end

  describe "metrics" do
    test "all metrics for breakdown by visit prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "signup",
          user_id: 1,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => [
            "visitors",
            "visits",
            "pageviews",
            "events",
            "bounce_rate",
            "visit_duration"
          ],
          "date_range" => "all",
          "dimensions" => ["visit:source"]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["Google"], "metrics" => [2, 2, 3, 4, 50, 300]},
               %{"dimensions" => ["Twitter"], "metrics" => [1, 1, 1, 1, 100, 0]}
             ]
    end

    test "metrics=bounce_rate does not add visits to the response", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          pathname: "/entry-page-1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/some-page",
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/entry-page-2",
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["bounce_rate"],
          "date_range" => "all",
          "dimensions" => ["visit:entry_page"],
          "order_by" => [["visit:entry_page", "asc"]]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/entry-page-1"], "metrics" => [0]},
               %{"dimensions" => ["/entry-page-2"], "metrics" => [100]}
             ]
    end

    test "all metrics for breakdown by event prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/plausible.io",
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview,
          pathname: "/plausible.io",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => [
            "visitors",
            "visits",
            "pageviews",
            "events",
            "bounce_rate",
            "visit_duration"
          ],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "order_by" => [["event:page", "desc"]]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/plausible.io"], "metrics" => [2, 2, 2, 2, 100, 0]},
               %{"dimensions" => ["/"], "metrics" => [2, 2, 2, 2, 50, 300]}
             ]
    end
  end

  test "filtering by custom event property", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:event,
        name: "Purchase",
        "meta.key": ["package"],
        "meta.value": ["business"],
        browser: "Chrome",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Purchase",
        "meta.key": ["package"],
        "meta.value": ["business"],
        browser: "Safari",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:event,
        name: "Purchase",
        "meta.key": ["package"],
        "meta.value": ["business"],
        browser: "Safari",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:event,
        name: "Purchase",
        "meta.key": ["package"],
        "meta.value": ["personal"],
        browser: "IE",
        timestamp: ~N[2021-01-01 00:25:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visit:browser"],
        "filters" => [
          ["is", "event:name", ["Purchase"]],
          ["is", "event:props:package", ["business"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Safari"], "metrics" => [2]},
             %{"dimensions" => ["Chrome"], "metrics" => [1]}
           ]
  end

  test "multiple breakdown timeseries with sources", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-02 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        timestamp: ~N[2021-01-02 00:00:00]
      ),
      build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
      build(:pageview,
        referrer_source: "Twitter",
        timestamp: ~N[2021-01-03 00:00:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => ["2021-01-01", "2021-01-03"],
        "dimensions" => ["time", "visit:source"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["2021-01-01", "Google"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-02", "Google"], "metrics" => [2]},
             %{"dimensions" => ["2021-01-02", "Direct / None"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-03", "Direct / None"], "metrics" => [2]},
             %{"dimensions" => ["2021-01-03", "Twitter"], "metrics" => [1]}
           ]
  end

  test "filtering by visit:country_name, visit:region_name, visit:city_name", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      # GB, London
      build(:pageview,
        country_code: "GB",
        subdivision1_code: "GB-LND",
        city_geoname_id: 2_643_743
      ),
      # CA, London
      build(:pageview,
        country_code: "CA",
        subdivision1_code: "CA-ON",
        city_geoname_id: 6_058_560
      ),
      # EE, Tallinn
      build(:pageview,
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409
      ),
      # EE, Tartu
      build(:pageview,
        country_code: "EE",
        subdivision1_code: "EE-79",
        city_geoname_id: 588_335
      ),
      # EE, Jõgeva
      build(:pageview,
        country_code: "EE",
        subdivision1_code: "EE-50",
        city_geoname_id: 591_902
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["pageviews"],
        "filters" => [
          ["is", "visit:country_name", ["Estonia", "United Kingdom"]],
          ["is_not", "visit:region_name", ["Tartumaa"]],
          ["contains", "visit:city_name", ["n"]]
        ],
        "dimensions" => ["visit:country_name", "visit:region_name", "visit:city_name"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Estonia", "Harjumaa", "Tallinn"], "metrics" => [1]},
             %{"dimensions" => ["United Kingdom", "London", "London"], "metrics" => [1]}
           ]
  end

  test "bounce rate calculation handles invalid session data gracefully", %{
    conn: conn,
    site: site
  } do
    # NOTE: At the time of this test is added, it appears it does _not_
    # catch the regression on MacOS (ARM), regardless if Clickhouse is run
    # natively or from a docker container. The test still does catch
    # that regression when ran on Linux for instance (including CI).
    user_id = System.unique_integer([:positive])

    populate_stats(site, [
      build(:pageview,
        user_id: user_id,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    first_session = Plausible.Cache.Adapter.get(:sessions, {site.id, user_id})

    populate_stats(site, [
      build(:pageview,
        user_id: user_id,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:01:00]
      )
    ])

    Plausible.Cache.Adapter.put(:sessions, {site.id, user_id}, first_session)

    populate_stats(site, [
      build(:pageview,
        user_id: user_id,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:01:00]
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["bounce_rate"],
        "dimensions" => ["event:page"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/"], "metrics" => [0]}
           ]
  end

  describe "using the returned query object in a new POST request" do
    test "yields the same results for a simple aggregate query", %{conn: conn, site: site} do
      Plausible.Site.changeset(site, %{timezone: "Europe/Tallinn"})
      |> Plausible.Repo.update()

      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn1 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all"
        })

      assert %{"results" => results1, "query" => query} = json_response(conn1, 200)
      assert results1 == [%{"metrics" => [3], "dimensions" => []}]

      conn2 = post(conn, "/api/v2/query", query)

      assert %{"results" => results2} = json_response(conn2, 200)
      assert results2 == [%{"metrics" => [3], "dimensions" => []}]
    end
  end

  describe "pagination" do
    setup %{site: site} = context do
      populate_stats(site, [
        build(:pageview, pathname: "/1"),
        build(:pageview, pathname: "/2"),
        build(:pageview, pathname: "/3"),
        build(:pageview, pathname: "/4"),
        build(:pageview, pathname: "/5"),
        build(:pageview, pathname: "/6"),
        build(:pageview, pathname: "/7"),
        build(:pageview, pathname: "/8")
      ])

      context
    end

    test "pagination above total count - all results are returned", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "order_by" => [["event:page", "asc"]],
          "include" => %{"total_rows" => true},
          "pagination" => %{"limit" => 10}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/1"], "metrics" => [1]},
               %{"dimensions" => ["/2"], "metrics" => [1]},
               %{"dimensions" => ["/3"], "metrics" => [1]},
               %{"dimensions" => ["/4"], "metrics" => [1]},
               %{"dimensions" => ["/5"], "metrics" => [1]},
               %{"dimensions" => ["/6"], "metrics" => [1]},
               %{"dimensions" => ["/7"], "metrics" => [1]},
               %{"dimensions" => ["/8"], "metrics" => [1]}
             ]

      assert json_response(conn, 200)["meta"]["total_rows"] == 8
    end

    test "pagination with offset", %{conn: conn, site: site} do
      query = %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "order_by" => [["event:page", "asc"]],
        "include" => %{"total_rows" => true}
      }

      conn1 = post(conn, "/api/v2/query", Map.put(query, "pagination", %{"limit" => 3}))

      assert json_response(conn1, 200)["results"] == [
               %{"dimensions" => ["/1"], "metrics" => [1]},
               %{"dimensions" => ["/2"], "metrics" => [1]},
               %{"dimensions" => ["/3"], "metrics" => [1]}
             ]

      assert json_response(conn1, 200)["meta"]["total_rows"] == 8

      conn2 =
        post(conn, "/api/v2/query", Map.put(query, "pagination", %{"limit" => 3, "offset" => 3}))

      assert json_response(conn2, 200)["results"] == [
               %{"dimensions" => ["/4"], "metrics" => [1]},
               %{"dimensions" => ["/5"], "metrics" => [1]},
               %{"dimensions" => ["/6"], "metrics" => [1]}
             ]

      assert json_response(conn2, 200)["meta"]["total_rows"] == 8

      conn3 =
        post(conn, "/api/v2/query", Map.put(query, "pagination", %{"limit" => 3, "offset" => 6}))

      assert json_response(conn3, 200)["results"] == [
               %{"dimensions" => ["/7"], "metrics" => [1]},
               %{"dimensions" => ["/8"], "metrics" => [1]}
             ]

      assert json_response(conn3, 200)["meta"]["total_rows"] == 8

      conn4 =
        post(conn, "/api/v2/query", Map.put(query, "pagination", %{"limit" => 3, "offset" => 9}))

      assert json_response(conn4, 200)["results"] == []
    end
  end

  describe "scroll_depth" do
    setup [:create_user, :create_site, :create_api_key, :use_api_key]

    test "scroll depth is (not yet) available in public API", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "filters" => [["is", "event:page", ["/"]]],
          "date_range" => "all",
          "metrics" => ["scroll_depth"]
        })

      assert json_response(conn, 400)["error"] =~ "Invalid metric \"scroll_depth\""
    end

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
