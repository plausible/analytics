defmodule PlausibleWeb.Api.ExternalStatsController.QueryTest do
  use PlausibleWeb.ConnCase
  alias Plausible.Billing.Feature

  @user_id 1231

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

  describe "feature access" do
    test "cannot break down by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:author"]
        })

      assert json_response(conn, 400)["error"] ==
               "The owner of this site does not have access to the custom properties feature"
    end

    test "can break down by an internal prop key without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:path"]
        })

      assert json_response(conn, 200)["results"]
    end

    test "cannot filter by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep =
        insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)

      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [["is", "event:props:author", ["Uku"]]]
        })

      assert json_response(conn, 400)["error"] ==
               "The owner of this site does not have access to the custom properties feature"
    end

    test "can filter by an internal prop key without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [["is", "event:props:url", ["whatever"]]]
        })

      assert json_response(conn, 200)["results"]
    end
  end

  describe "param validation" do
    test "does not allow querying conversion_rate without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["conversion_rate"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [["is", "event:props:author", ["Uku"]]]
        })

      assert json_response(conn, 400)["error"] ==
               "Metric `conversion_rate` can only be queried with event:goal filters or dimensions"
    end

    test "validates that dimensions are valid", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["badproperty"]
        })

      assert json_response(conn, 400)["error"] =~ "Invalid dimensions"
    end

    test "empty custom property is invalid", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:"]
        })

      assert json_response(conn, 400)["error"] =~ "Invalid dimensions"
    end

    test "validates that correct date range is used", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "bad_period",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] =~ "Invalid date_range"
    end

    test "fails when an invalid metric is provided", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "baa"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] =~ "Unknown metric '\"baa\"'"
    end

    test "session metrics cannot be used with event:name dimension", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "bounce_rate"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] =~
               "Session metric(s) `bounce_rate` cannot be queried along with event dimensions"
    end

    test "session metrics cannot be used with event:props:* dimension", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "bounce_rate"],
          "date_range" => "all",
          "dimensions" => ["event:props:url"]
        })

      assert json_response(conn, 400)["error"] =~
               "Session metric(s) `bounce_rate` cannot be queried along with event dimensions"
    end

    test "validates that metric views_per_visit cannot be used with event:page filter", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit"],
          "filters" => [["is", "event:page", ["/something"]]]
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Metric `views_per_visit` cannot be queried with a filter on `event:page`"
             }
    end

    test "validates that metric views_per_visit cannot be used together with dimensions", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit"],
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400) == %{
               "error" => "Metric `views_per_visit` cannot be queried with `dimensions`"
             }
    end

    test "validates a metric can't be asked multiple times", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit", "visitors", "visitors"]
        })

      assert json_response(conn, 400) == %{
               "error" => "Metrics cannot be queried multiple times"
             }
    end
  end

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

    test "wildcard referrer filter with special regex characters", %{conn: conn, site: site} do
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
            ["matches", "visit:referrer", ["**a.com**"]]
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
            ["matches", "event:hostname", ["*.example.com", "example.com"]]
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
            ["matches", "event:goal", ["Visit /blog**"]]
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
            ["matches", "event:goal", ["Signup", "Visit /**register"]]
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

    test "wildcard page filter", %{conn: conn, site: site} do
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
            ["matches", "event:page", ["/en/**"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
    end

    test "negated wildcard page filter", %{conn: conn, site: site} do
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
            ["does_not_match", "event:page", ["/en/**"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "wildcard and member filter combined", %{conn: conn, site: site} do
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
            ["matches", "event:page", ["/en/**", "/pl/**"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "can escape pipe character in member + wildcard filter", %{conn: conn, site: site} do
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
            ["matches", "event:page", ["**post\\|1", "/something-else"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end

    test "handles filtering by visit country", %{
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
  end

  describe "aggregation with imported data" do
    setup :create_site_import

    test "does not count imported stats unless specified", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_visitors, date: ~D[2023-01-01]),
        build(:pageview, timestamp: ~N[2023-01-01 00:00:00])
      ])

      query_params = %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["pageviews"]
      }

      conn1 = post(conn, "/api/v2/query", query_params)

      assert json_response(conn1, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]

      conn2 = post(conn, "/api/v2/query", Map.put(query_params, "include", %{"imports" => true}))

      assert json_response(conn2, 200)["results"] == [%{"metrics" => [2], "dimensions" => []}]
      refute json_response(conn2, 200)["meta"]["warning"]
    end
  end

  describe "timeseries" do
    test "shows hourly data for a certain date", %{conn: conn, site: site} do
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
          "dimensions" => ["time:hour"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01T00:00:00Z"], "metrics" => [1, 2, 1, 600, 0]},
               %{"dimensions" => ["2021-01-01T23:00:00Z"], "metrics" => [1, 1, 1, 0, 100]}
             ]
    end

    test "shows last 7 days of visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => ["2021-01-01", "2021-01-07"],
          "dimensions" => ["time"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-07"], "metrics" => [1]}
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
          "dimensions" => ["time"]
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
          "dimensions" => ["time"]
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
          "dimensions" => ["time:day"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2020-02-01"], "metrics" => [1]},
               %{"dimensions" => ["2020-12-31"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]}
             ]
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

  test "breaks down all metrics by visit:referrer with imported data", %{conn: conn, site: site} do
    site_import =
      insert(:site_import,
        site: site,
        start_date: ~D[2005-01-01],
        end_date: Timex.today(),
        source: :universal_analytics
      )

    populate_stats(site, site_import.id, [
      build(:pageview, referrer: "site.com", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, referrer: "site.com/1", timestamp: ~N[2021-01-01 00:00:00]),
      build(:imported_sources,
        referrer: "site.com",
        date: ~D[2021-01-01],
        visitors: 2,
        visits: 2,
        pageviews: 2,
        bounces: 1,
        visit_duration: 120
      ),
      build(:imported_sources,
        referrer: "site.com/2",
        date: ~D[2021-01-01],
        visitors: 2,
        visits: 2,
        pageviews: 2,
        bounces: 2,
        visit_duration: 0
      ),
      build(:imported_sources,
        date: ~D[2021-01-01],
        visitors: 10,
        visits: 11,
        pageviews: 50,
        bounces: 0,
        visit_duration: 1100
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "visits", "pageviews", "bounce_rate", "visit_duration"],
        "date_range" => "all",
        "dimensions" => ["visit:referrer"],
        "include" => %{"imports" => true}
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Direct / None"], "metrics" => [10, 11, 50, 0.0, 100.0]},
             %{"dimensions" => ["site.com"], "metrics" => [3, 3, 3, 67.0, 40.0]},
             %{"dimensions" => ["site.com/2"], "metrics" => [2, 2, 2, 100.0, 0.0]},
             %{"dimensions" => ["site.com/1"], "metrics" => [1, 1, 1, 100.0, 0.0]}
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

  test "breaks down all metrics by visit:utm_source with imported data", %{conn: conn, site: site} do
    site_import =
      insert(:site_import,
        site: site,
        start_date: ~D[2005-01-01],
        end_date: Timex.today(),
        source: :universal_analytics
      )

    populate_stats(site, site_import.id, [
      build(:pageview, utm_source: "SomeUTMSource", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, utm_source: "SomeUTMSource-1", timestamp: ~N[2021-01-01 00:00:00]),
      build(:imported_sources,
        utm_source: "SomeUTMSource",
        date: ~D[2021-01-01],
        visitors: 2,
        visits: 2,
        pageviews: 2,
        bounces: 1,
        visit_duration: 120
      ),
      build(:imported_sources,
        utm_source: "SomeUTMSource-2",
        date: ~D[2021-01-01],
        visitors: 2,
        visits: 2,
        pageviews: 2,
        bounces: 2,
        visit_duration: 0
      ),
      build(:imported_sources,
        date: ~D[2021-01-01],
        visitors: 10,
        visits: 11,
        pageviews: 50,
        bounces: 0,
        visit_duration: 1100
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "visits", "pageviews", "bounce_rate", "visit_duration"],
        "date_range" => "all",
        "dimensions" => ["visit:utm_source"],
        "include" => %{"imports" => true}
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["SomeUTMSource"], "metrics" => [3, 3, 3, 67.0, 40.0]},
             %{"dimensions" => ["SomeUTMSource-2"], "metrics" => [2, 2, 2, 100.0, 0.0]},
             %{"dimensions" => ["SomeUTMSource-1"], "metrics" => [1, 1, 1, 100.0, 0.0]}
           ]
  end

  test "pageviews breakdown by event:page - imported data having pageviews=0 and visitors=n should be bypassed",
       %{conn: conn, site: site} do
    site_import =
      insert(:site_import,
        site: site,
        start_date: ~D[2005-01-01],
        end_date: Timex.today(),
        source: :universal_analytics
      )

    populate_stats(site, site_import.id, [
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:imported_pages,
        page: "/skip-me",
        date: ~D[2021-01-01],
        visitors: 1,
        pageviews: 0
      ),
      build(:imported_pages,
        page: "/include-me",
        date: ~D[2021-01-01],
        visitors: 1,
        pageviews: 1
      )
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true}
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/"], "metrics" => [2]},
             %{"dimensions" => ["/plausible.io"], "metrics" => [1]},
             %{"dimensions" => ["/include-me"], "metrics" => [1]}
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
        "dimensions" => ["event:hostname"],
        "with_imported" => "true"
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["a.example.com"], "metrics" => [3]},
             %{"dimensions" => ["b.example.com"], "metrics" => [1]}
           ]
  end

  describe "breakdown by visit:exit_page" do
    setup %{site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          pathname: "/a",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          pathname: "/a",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          user_id: @user_id,
          pathname: "/b",
          timestamp: ~N[2021-01-01 00:35:00]
        ),
        build(:imported_exit_pages,
          exit_page: "/b",
          exits: 3,
          visitors: 2,
          pageviews: 5,
          date: ~D[2021-01-01]
        )
      ])
    end

    test "can query with visit:exit_page dimension", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visits"],
          "date_range" => "all",
          "dimensions" => ["visit:exit_page"],
          "include" => %{"imports" => true}
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/b"], "metrics" => [4]},
               %{"dimensions" => ["/a"], "metrics" => [1]}
             ]
    end
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
            ["matches", "event:page", ["/pageA"]]
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
            ["matches", "event:page", ["/en/**"]]
          ]
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [
               %{"dimensions" => ["/en/page2"], "metrics" => [2]},
               %{"dimensions" => ["/en/page1"], "metrics" => [1]}
             ]
    end

    test "can filter event:hostname with a wildcard", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, hostname: "alice.example.com", pathname: "/a"),
        build(:pageview, hostname: "anna.example.com", pathname: "/a"),
        build(:pageview, hostname: "adam.example.com", pathname: "/a"),
        build(:pageview, hostname: "bob.example.com", pathname: "/b")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["matches", "event:hostname", ["a*.example.com"]]
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
          "dimensions" => ["event:props:package"],
          "filters" => []
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

  describe "breakdown by event:goal" do
    test "returns custom event goals and pageview goals", %{conn: conn, site: site} do
      insert(:goal, %{site: site, event_name: "Purchase"})
      insert(:goal, %{site: site, page_path: "/test"})

      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Purchase"], "metrics" => [2]},
               %{"dimensions" => ["Visit /test"], "metrics" => [1]}
             ]
    end

    test "returns pageview goals containing wildcards", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/**/post"})
      insert(:goal, %{site: site, page_path: "/blog**"})

      populate_stats(site, [
        build(:pageview, pathname: "/blog", user_id: @user_id),
        build(:pageview, pathname: "/blog/post-1", user_id: @user_id),
        build(:pageview, pathname: "/blog/post-2", user_id: @user_id),
        build(:pageview, pathname: "/blog/something/post"),
        build(:pageview, pathname: "/different/page/post")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "dimensions" => ["event:goal"],
          "order_by" => [["pageviews", "desc"]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 4]},
               %{"dimensions" => ["Visit /**/post"], "metrics" => [2, 2]}
             ]
    end

    test "does not return goals that are not configured for the site", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == []
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
          ["matches", "event:goal", ["Visit /**register"]]
        ]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["/en/register"], "metrics" => [2, 3]},
             %{"dimensions" => ["/123/it/register"], "metrics" => [1, 1]}
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
          ["matches", "event:goal", ["Signup", "Visit /**register"]]
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
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "property" => "event:page",
        "filters" => "event:goal == Register"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"page" => "/en/register", "visitors" => 2},
               %{"page" => "/it/register", "visitors" => 1}
             ]
           }

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

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/plausible.io"], "metrics" => [100]},
             %{"dimensions" => ["/important-page"], "metrics" => [100]}
           ]
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
    test "returns conversion_rate in an event:goal breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", user_id: 1),
        build(:event, name: "Signup", user_id: 1),
        build(:pageview, pathname: "/blog"),
        build(:pageview, pathname: "/blog/post"),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/blog**"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events", "conversion_rate"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["Signup"], "metrics" => [1, 2, 25.0]}
             ]
    end

    test "returns conversion_rate alone in an event:goal breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", user_id: 1),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["conversion_rate"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [50.0]}
             ]
    end

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
          "filters" => [["matches", "event:goal", ["Visit /blog**"]]],
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
          "filters" => [["matches", "event:goal", ["Visit /blog**"]]]
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
               %{"dimensions" => ["/en/register"], "metrics" => [2, 2, 66.7]},
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
               %{"dimensions" => ["Mobile"], "metrics" => [2, 2, 66.7]},
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
          "dimensions" => ["visit:source"],
          "filters" => []
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

    test "filter by custom event property", %{conn: conn, site: site} do
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
          "dimensions" => ["event:page"]
        })

      %{"results" => results} = json_response(conn, 200)

      assert %{"dimensions" => ["/plausible.io"], "metrics" => [2, 2, 2, 2, 100, 0]} in results
      assert %{"dimensions" => ["/"], "metrics" => [2, 2, 2, 2, 50, 300]} in results
    end
  end

  describe "imported data" do
    test "returns screen sizes breakdown when filtering by screen size", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          screen_size: "Mobile"
        ),
        build(:imported_devices,
          device: "Mobile",
          visitors: 3,
          pageviews: 5,
          date: ~D[2021-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "pageviews"],
          "date_range" => "all",
          "dimensions" => ["visit:device"],
          "filters" => [
            ["is", "visit:device", ["Mobile"]]
          ],
          "include" => %{"imports" => true}
        })

      %{"results" => results} = json_response(conn, 200)

      assert results == [%{"dimensions" => ["Mobile"], "metrics" => [4, 6]}]
    end

    test "returns custom event goals and pageview goals", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, page_path: "/test")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "dimensions" => ["event:goal"],
          "metrics" => ["visitors", "events", "pageviews", "conversion_rate"],
          "include" => %{"imports" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Purchase"], "metrics" => [5, 7, 0, 62.5]},
               %{"dimensions" => ["Visit /test"], "metrics" => [3, 3, 3, 37.5]}
             ]
    end

    test "pageviews are returned as events for breakdown reports other than custom events", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_browsers, browser: "Chrome", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_devices, device: "Desktop", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_entry_pages, entry_page: "/test", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_exit_pages, exit_page: "/test", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_locations, country: "EE", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_operating_systems,
          operating_system: "Mac",
          pageviews: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/test", pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_sources, source: "Google", pageviews: 1, date: ~D[2021-01-01])
      ])

      breakdown_and_first = fn dimension ->
        conn
        |> post("/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["events"],
          "date_range" => ["2021-01-01", "2021-01-01"],
          "dimensions" => [dimension],
          "include" => %{"imports" => true}
        })
        |> json_response(200)
        |> Map.get("results")
        |> List.first()
      end

      assert %{"dimensions" => ["Chrome"], "metrics" => [1]} =
               breakdown_and_first.("visit:browser")

      assert %{"dimensions" => ["Desktop"], "metrics" => [1]} =
               breakdown_and_first.("visit:device")

      assert %{"dimensions" => ["EE"], "metrics" => [1]} = breakdown_and_first.("visit:country")
      assert %{"dimensions" => ["Mac"], "metrics" => [1]} = breakdown_and_first.("visit:os")
      assert %{"dimensions" => ["/test"], "metrics" => [1]} = breakdown_and_first.("event:page")

      assert %{"dimensions" => ["Google"], "metrics" => [1]} =
               breakdown_and_first.("visit:source")
    end

    for goal_name <- Plausible.Imported.goals_with_url() do
      test "returns url breakdown for #{goal_name} goal", %{conn: conn, site: site} do
        insert(:goal, event_name: unquote(goal_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(goal_name),
            "meta.key": ["url"],
            "meta.value": ["https://one.com"]
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 2,
            events: 5,
            link_url: "https://one.com"
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 5,
            events: 10,
            link_url: "https://two.com"
          ),
          build(:imported_custom_events,
            name: "some goal",
            visitors: 5,
            events: 10
          ),
          build(:imported_visitors, visitors: 9)
        ])

        conn =
          post(conn, "/api/v2/query", %{
            "site_id" => site.domain,
            "metrics" => ["visitors", "events", "conversion_rate"],
            "date_range" => "all",
            "dimensions" => ["event:props:url"],
            "filters" => [
              ["is", "event:goal", [unquote(goal_name)]]
            ],
            "include" => %{"imports" => true}
          })

        assert json_response(conn, 200)["results"] == [
                 %{"dimensions" => ["https://two.com"], "metrics" => [5, 10, 50]},
                 %{"dimensions" => ["https://one.com"], "metrics" => [3, 6, 30]}
               ]

        refute json_response(conn, 200)["meta"]["warning"]
      end
    end

    for goal_name <- Plausible.Imported.goals_with_path() do
      test "returns path breakdown for #{goal_name} goal", %{conn: conn, site: site} do
        insert(:goal, event_name: unquote(goal_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(goal_name),
            "meta.key": ["path"],
            "meta.value": ["/one"]
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 2,
            events: 5,
            path: "/one"
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 5,
            events: 10,
            path: "/two"
          ),
          build(:imported_custom_events,
            name: "some goal",
            visitors: 5,
            events: 10
          ),
          build(:imported_visitors, visitors: 9)
        ])

        conn =
          post(conn, "/api/v2/query", %{
            "site_id" => site.domain,
            "metrics" => ["visitors", "events", "conversion_rate"],
            "date_range" => "all",
            "dimensions" => ["event:props:path"],
            "filters" => [
              ["is", "event:goal", [unquote(goal_name)]]
            ],
            "include" => %{"imports" => true}
          })

        assert json_response(conn, 200)["results"] == [
                 %{"dimensions" => ["/two"], "metrics" => [5, 10, 50]},
                 %{"dimensions" => ["/one"], "metrics" => [3, 6, 30]}
               ]

        refute json_response(conn, 200)["meta"]["warning"]
      end
    end

    test "adds a warning when query params are not supported for imported data", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      insert(:goal, event_name: "Signup", site: site)

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Signup",
          "meta.key": ["package"],
          "meta.value": ["large"]
        ),
        build(:imported_visitors, visitors: 9)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:package"],
          "filters" => [
            ["is", "event:goal", ["Signup"]]
          ],
          "include" => %{"imports" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["large"], "metrics" => [1]}
             ]

      assert json_response(conn, 200)["meta"]["warning"] =~
               "Imported stats are not included in the results because query parameters are not supported."
    end

    test "does not add a warning when there are no site imports", %{conn: conn, site: site} do
      insert(:goal, event_name: "Signup", site: site)

      populate_stats(site, [
        build(:event,
          name: "Signup",
          "meta.key": ["package"],
          "meta.value": ["large"]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:package"],
          "filters" => [
            ["is", "event:goal", ["Signup"]]
          ],
          "include" => %{"imports" => true}
        })

      refute json_response(conn, 200)["meta"]["warning"]
    end

    test "does not add a warning when import is out of queried date range", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site, end_date: Date.add(Date.utc_today(), -3))

      insert(:goal, event_name: "Signup", site: site)

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Signup",
          "meta.key": ["package"],
          "meta.value": ["large"]
        ),
        build(:imported_visitors, visitors: 9)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "day",
          "dimensions" => ["event:props:package"],
          "filters" => [
            ["is", "event:goal", ["Signup"]]
          ],
          "include" => %{"imports" => true}
        })

      refute json_response(conn, 200)["meta"]["warning"]
    end

    test "applies multiple filters if the properties belong to the same table", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_sources, source: "Google", utm_medium: "organic", utm_term: "one"),
        build(:imported_sources, source: "Twitter", utm_medium: "organic", utm_term: "two"),
        build(:imported_sources,
          source: "Facebook",
          utm_medium: "something_else",
          utm_term: "one"
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "day",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["is", "visit:utm_medium", ["organic"]],
            ["is", "visit:utm_term", ["one"]]
          ],
          "include" => %{"imports" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Google"], "metrics" => [1]}
             ]
    end

    test "ignores imported data if filtered property belongs to a different table than the breakdown property",
         %{
           conn: conn,
           site: site
         } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_sources, source: "Google"),
        build(:imported_devices, device: "Desktop")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "day",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["is", "visit:device", ["Desktop"]]
          ],
          "include" => %{"imports" => true}
        })

      assert %{
               "results" => [],
               "meta" => meta
             } = json_response(conn, 200)

      assert meta["warning"] =~ "Imported stats are not included in the results"
    end

    test "imported country, region and city data",
         %{
           conn: conn,
           site: site
         } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00],
          country_code: "DE",
          subdivision1_code: "DE-BE",
          city_geoname_id: 2_950_159
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00],
          country_code: "DE",
          subdivision1_code: "DE-BE",
          city_geoname_id: 2_950_159
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00],
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:imported_locations, country: "EE", region: "EE-37", city: 588_409, visitors: 33)
      ])

      for {dimension, stats_value, imports_value} <- [
            {"visit:country", "DE", "EE"},
            {"visit:region", "DE-BE", "EE-37"},
            {"visit:city", 2_950_159, 588_409}
          ] do
        conn =
          post(conn, "/api/v2/query", %{
            "site_id" => site.domain,
            "metrics" => ["visitors"],
            "date_range" => "all",
            "dimensions" => [dimension],
            "include" => %{"imports" => true}
          })

        assert json_response(conn, 200)["results"] == [
                 %{"dimensions" => [imports_value], "metrics" => [34]},
                 %{"dimensions" => [stats_value], "metrics" => [2]}
               ]
      end
    end
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
             %{"dimensions" => ["2021-01-01T00:00:00Z", "Google"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-02T00:00:00Z", "Google"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-02T00:00:00Z", "Direct / None"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-03T00:00:00Z", "Direct / None"], "metrics" => [1]},
             %{"dimensions" => ["2021-01-03T00:00:00Z", "Twitter"], "metrics" => [1]}
           ]
  end
end
