defmodule PlausibleWeb.Api.ExternalStatsController.AggregateTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  alias Plausible.Billing.Feature

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]
  @user_id 123

  describe "feature access" do
    test "cannot filter by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "filters" => "event:props:author==Uku"
        })

      assert json_response(conn, 402)["error"] ==
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "filters" => "event:props:url==https://site.com"
        })

      assert json_response(conn, 200)["results"]
    end
  end

  describe "param validation" do
    test "validates that date can be parsed", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-dkjbAS",
          "metrics" => "pageviews"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `date` parameter: invalid_format. Please specify a valid date in ISO-8601 format."
             }
    end

    test "validates that period can be parsed", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "aosuhsacp",
          "metrics" => "pageviews"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `period` parameter: invalid period `aosuhsacp`. Please find accepted values in our docs: https://plausible.io/docs/stats-api#time-periods"
             }
    end

    test "custom period is not valid without a date", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "custom",
          "metrics" => "pageviews"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "The `date` parameter is required when using a custom period. See https://plausible.io/docs/stats-api#time-periods"
             }
    end

    test "validates date format in custom period", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2020-131-2piaskj,s,a90uac",
          "metrics" => "pageviews"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Invalid format for `date` parameter. When using a custom period, please include two ISO-8601 formatted dates joined by a comma. See https://plausible.io/docs/stats-api#time-periods"
             }
    end

    test "validates that metrics are all recognized", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "30d",
          "metrics" => "pageviews,led_zeppelin"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "The metric `led_zeppelin` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#metrics"
             }
    end

    test "validates that session metrics cannot be used with event:name filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "30d",
          "metrics" => "pageviews,visit_duration",
          "filters" => "event:name==Signup"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Session metric `visit_duration` cannot be queried when using a filter on `event:name`."
             }
    end

    test "validates that views_per_visit cannot be used with event:page filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "filters" => "event:page==/something",
          "metrics" => "views_per_visit"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Metric `views_per_visit` cannot be queried with a filter on `event:page`."
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
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "pageviews"
      })

    assert json_response(conn, 200)["results"] == %{
             "pageviews" => %{"value" => 3}
           }
  end

  test "rounds views_per_visit to two decimal places", %{
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
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "views_per_visit"
      })

    assert json_response(conn, 200)["results"] == %{
             "views_per_visit" => %{"value" => 1.67}
           }
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
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "pageviews,visits,views_per_visit,visitors,bounce_rate,visit_duration"
      })

    assert json_response(conn, 200)["results"] == %{
             "pageviews" => %{"value" => 3},
             "visitors" => %{"value" => 2},
             "visits" => %{"value" => 2},
             "views_per_visit" => %{"value" => 1.5},
             "bounce_rate" => %{"value" => 50},
             "visit_duration" => %{"value" => 750}
           }
  end

  describe "comparisons" do
    test "compare period=day with previous period", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview,
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "compare" => "previous_period"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 3, "change" => 200},
               "visitors" => %{"value" => 2, "change" => 100},
               "bounce_rate" => %{"value" => 50, "change" => -50},
               "visit_duration" => %{"value" => 750, "change" => 100}
             }
    end

    test "compare period=6mo with previous period", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-02-01 00:25:00]
        ),
        build(:pageview, timestamp: ~N[2021-03-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "6mo",
          "date" => "2021-03-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "compare" => "previous_period"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 4, "change" => 100},
               "visitors" => %{"value" => 3, "change" => 100},
               "bounce_rate" => %{"value" => 100, "change" => 100},
               "visit_duration" => %{"value" => 0, "change" => 0}
             }
    end
  end

  describe "with imported data" do
    setup :add_imported_data

    test "does not count imported stats unless specified", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2023-01-01]),
        build(:pageview, timestamp: ~N[2023-01-01 00:00:00])
      ])

      query_params = %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2023-01-01",
        "metrics" => "pageviews"
      }

      conn1 = get(conn, "/api/v1/stats/aggregate", query_params)

      assert json_response(conn1, 200)["results"] == %{
               "pageviews" => %{"value" => 1}
             }

      conn2 = get(conn, "/api/v1/stats/aggregate", Map.put(query_params, "with_imported", "true"))

      assert json_response(conn2, 200)["results"] == %{
               "pageviews" => %{"value" => 2}
             }
    end

    test "counts imported stats when comparing with previous period", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors,
          visits: 2,
          bounces: 1,
          visit_duration: 200,
          pageviews: 10,
          date: ~D[2023-01-01]
        ),
        build(:imported_visitors,
          visits: 4,
          bounces: 1,
          visit_duration: 100,
          pageviews: 8,
          date: ~D[2023-01-02]
        ),
        build(:pageview, timestamp: ~N[2023-01-02 00:10:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2023-01-02,2023-01-02",
          "metrics" => "visitors,visits,pageviews,views_per_visit,bounce_rate,visit_duration",
          "compare" => "previous_period",
          "with_imported" => "true"
        })

      assert json_response(conn, 200)["results"] == %{
               "visitors" => %{"value" => 2, "change" => 100},
               "visits" => %{"value" => 5, "change" => 150},
               "pageviews" => %{"value" => 9, "change" => -10},
               "bounce_rate" => %{"value" => 40, "change" => -20},
               "views_per_visit" => %{"value" => 1.0, "change" => 100},
               "visit_duration" => %{"value" => 20, "change" => -80}
             }
    end

    test "ignores imported data when filters are applied", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2023-01-01]),
        build(:imported_sources, date: ~D[2023-01-01]),
        build(:pageview, referrer_source: "Google", timestamp: ~N[2023-01-02 00:10:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2023-01-02",
          "metrics" => "visitors",
          "filters" => "visit:source==Google",
          "compare" => "previous_period",
          "with_imported" => "true"
        })

      assert json_response(conn, 200)["results"] == %{
               "visitors" => %{"value" => 1, "change" => 100}
             }
    end

    test "events metric with imported data is disallowed", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2023-01-01])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2023-01-02",
          "metrics" => "events",
          "with_imported" => "true"
        })

      assert %{"error" => msg} = json_response(conn, 400)
      assert msg == "Metric `events` cannot be queried with imported data"
    end
  end

  describe "filters" do
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:source==Google"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:source==Direct / None"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:referrer==https://facebook.com"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "wildcard referrer filter with special regex characters", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer: "https://a.com"),
        build(:pageview, referrer: "https://a.com"),
        build(:pageview, referrer: "https://ab.com")
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "visitors",
          "filters" => "visit:referrer==**a.com**"
        })

      assert json_response(conn, 200)["results"] == %{"visitors" => %{"value" => 2}}
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_medium==social"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_source==Twitter"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_campaign==profile"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:device==Desktop"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:browser==Chrome"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:browser_version==56"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:os==Mac"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:os_version==10.5"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:country==EE"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "event:page==/blogpost"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 2},
               "bounce_rate" => %{"value" => 100},
               "visit_duration" => %{"value" => 750}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "visitors,pageviews",
          "filters" => "event:name==Signup"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 0},
               "visitors" => %{"value" => 2}
             }
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "event:page==/blogpost;visit:country==EE"
        })

      assert json_response(conn, 200)["results"] == %{
               "pageviews" => %{"value" => 1},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "wildcard page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1")
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "visitors",
          "filters" => "event:page==/en/**"
        })

      assert json_response(conn, 200)["results"] == %{"visitors" => %{"value" => 2}}
    end

    test "negated wildcard page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1")
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "visitors",
          "filters" => "event:page!=/en/**"
        })

      assert json_response(conn, 200)["results"] == %{"visitors" => %{"value" => 1}}
    end

    test "wildcard and member filter combined", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/en/page1"),
        build(:pageview, pathname: "/en/page2"),
        build(:pageview, pathname: "/pl/page1"),
        build(:pageview, pathname: "/ee/page1")
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "visitors",
          "filters" => "event:page==/en/**|/pl/**"
        })

      assert json_response(conn, 200)["results"] == %{"visitors" => %{"value" => 3}}
    end

    test "can escape pipe character in member + wildcard filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post|1"),
        build(:pageview, pathname: "/otherpost|1"),
        build(:pageview, pathname: "/blog/post|2"),
        build(:pageview, pathname: "/something-else")
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "visitors",
          "filters" => "event:page==**post\\|1|/something-else"
        })

      assert json_response(conn, 200)["results"] == %{"visitors" => %{"value" => 3}}
    end

    test "joins correctly with the sessions (CollapsingMergeTree) table", %{
      conn: conn,
      site: site
    } do
      create_sessions([
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          sign: 1,
          events: 1
        },
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          sign: -1,
          events: 1
        },
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          sign: 1,
          events: 2
        }
      ])

      create_events([
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          name: "pageview"
        },
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          name: "pageview"
        },
        %{
          site_id: site.id,
          session_id: 1000,
          country_code: "EE",
          name: "pageview"
        }
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "metrics" => "pageviews",
          "filters" => "visit:country==EE"
        })

      assert json_response(conn, 200)["results"] == %{"pageviews" => %{"value" => 3}}
    end
  end
end
