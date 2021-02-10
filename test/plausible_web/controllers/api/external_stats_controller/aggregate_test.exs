defmodule PlausibleWeb.Api.ExternalStatsController.AggregateTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]
  @user_id 123

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

    test "validates that metrics are all recognized", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "30d",
          "metrics" => "pageviews,led_zeppelin"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `metrics` parameter: invalid metric `led_zeppelin`. Valid metrics are `pageviews`, `visitors`, `bounce_rate`, `visit_duration`"
             }
    end
  end

  test "aggregates a single metric", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "pageviews"
      })

    assert json_response(conn, 200) == %{
             "pageviews" => %{"value" => 3}
           }
  end

  test "aggregates visitors, pageviews, bounce rate and visit duration", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "pageviews,visitors,bounce_rate,visit_duration"
      })

    assert json_response(conn, 200) == %{
             "pageviews" => %{"value" => 3},
             "visitors" => %{"value" => 2},
             "bounce_rate" => %{"value" => 50},
             "visit_duration" => %{"value" => 750}
           }
  end

  describe "comparisons" do
    test "compare period=day with previous period", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "compare" => "previous_period"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 3, "change" => 200},
               "visitors" => %{"value" => 2, "change" => 100},
               "bounce_rate" => %{"value" => 50, "change" => -50},
               "visit_duration" => %{"value" => 750, "change" => 100}
             }
    end
  end

  describe "filters" do
    test "can filter by source", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          referrer_source: "Google",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:source==Google"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by no source/referrer", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          domain: site.domain,
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

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by referrer", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          referrer: "https://facebook.com",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:referrer==https://facebook.com"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by utm_medium", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_medium: "social",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_medium==social"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by utm_source", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_source: "Twitter",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_source==Twitter"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by utm_campaign", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_campaign: "profile",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:utm_campaign==profile"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by device type", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          screen_size: "Desktop",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:device==Desktop"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by browser", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          browser: "Chrome",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:browser==Chrome"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by browser version", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          browser: "Chrome",
          browser_version: "56",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:browser_version==56"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by operating system", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          operating_system: "Mac",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:os==Mac"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by operating system version", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          operating_system_version: "10.5",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:os_version==10.5"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "can filter by country", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "pageviews,visitors,bounce_rate,visit_duration",
          "filters" => "visit:country==EE"
        })

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end

    test "when filtering by page, session metrics treat is like entry_page", %{
      conn: conn,
      site: site
    } do
      populate_stats([
        build(:pageview,
          pathname: "/blogpost",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          pathname: "/blogpost",
          domain: site.domain,
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

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 2},
               "visitors" => %{"value" => 2},
               "bounce_rate" => %{"value" => 50},
               "visit_duration" => %{"value" => 750}
             }
    end

    test "combining filters", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          pathname: "/blogpost",
          country_code: "EE",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          pathname: "/blogpost",
          domain: site.domain,
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

      assert json_response(conn, 200) == %{
               "pageviews" => %{"value" => 1},
               "visitors" => %{"value" => 1},
               "bounce_rate" => %{"value" => 0},
               "visit_duration" => %{"value" => 1500}
             }
    end
  end
end
