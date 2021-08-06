defmodule PlausibleWeb.Api.ExternalStatsController.TimeseriesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

  describe "param validation" do
    test "validates that date can be parsed", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "6mo",
          "date" => "2021-dkjbAS"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `date` parameter: invalid_format. Please specify a valid date in ISO-8601 format."
             }
    end

    test "validates that period can be parsed", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "aosuhsacp"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `period` parameter: invalid period `aosuhsacp`. Please find accepted values in our docs: https://plausible.io/docs/stats-api#time-periods"
             }
    end

    test "validates that interval is `date` or `month`", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "12mo",
          "interval" => "alskd"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `interval` parameter: invalid interval `alskd`. Valid intervals are `date`, `month`"
             }
    end
  end

  @user_id 123
  test "shows hourly data for a certain date", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00]),
      build(:pageview, timestamp: ~N[2021-01-01 23:59:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "metrics" => "visitors,pageviews,visits,visit_duration,bounce_rate"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{
                 "date" => "2021-01-01 00:00:00",
                 "visitors" => 1,
                 "visits" => 1,
                 "pageviews" => 2,
                 "visit_duration" => 600,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 01:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 02:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 03:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 04:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 05:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 06:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 07:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 08:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 09:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 10:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 11:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 12:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 13:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 14:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 15:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 16:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 17:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 18:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 19:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 20:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 21:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 22:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => nil
               },
               %{
                 "date" => "2021-01-01 23:00:00",
                 "visitors" => 1,
                 "visits" => 1,
                 "pageviews" => 1,
                 "visit_duration" => 0,
                 "bounce_rate" => 100
               }
             ]
           }
  end

  test "shows last 7 days of visitors", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-07 23:59:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "7d",
        "date" => "2021-01-07"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"date" => "2021-01-01", "visitors" => 1},
               %{"date" => "2021-01-02", "visitors" => 0},
               %{"date" => "2021-01-03", "visitors" => 0},
               %{"date" => "2021-01-04", "visitors" => 0},
               %{"date" => "2021-01-05", "visitors" => 0},
               %{"date" => "2021-01-06", "visitors" => 0},
               %{"date" => "2021-01-07", "visitors" => 1}
             ]
           }
  end

  test "shows last 6 months of visitors", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "6mo",
        "date" => "2021-01-01"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"date" => "2020-08-01", "visitors" => 0},
               %{"date" => "2020-09-01", "visitors" => 0},
               %{"date" => "2020-10-01", "visitors" => 0},
               %{"date" => "2020-11-01", "visitors" => 0},
               %{"date" => "2020-12-01", "visitors" => 1},
               %{"date" => "2021-01-01", "visitors" => 2}
             ]
           }
  end

  test "shows last 12 months of visitors", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2020-02-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "12mo",
        "date" => "2021-01-01"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"date" => "2020-02-01", "visitors" => 1},
               %{"date" => "2020-03-01", "visitors" => 0},
               %{"date" => "2020-04-01", "visitors" => 0},
               %{"date" => "2020-05-01", "visitors" => 0},
               %{"date" => "2020-06-01", "visitors" => 0},
               %{"date" => "2020-07-01", "visitors" => 0},
               %{"date" => "2020-08-01", "visitors" => 0},
               %{"date" => "2020-09-01", "visitors" => 0},
               %{"date" => "2020-10-01", "visitors" => 0},
               %{"date" => "2020-11-01", "visitors" => 0},
               %{"date" => "2020-12-01", "visitors" => 1},
               %{"date" => "2021-01-01", "visitors" => 2}
             ]
           }
  end

  test "shows last 12 months of visitors with interval daily", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2020-02-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "12mo",
        "interval" => "date"
      })

    res = json_response(conn, 200)
    assert Enum.count(res["results"]) in [365, 366]
  end

  test "shows a custom range with daily interval", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-02 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "custom",
        "date" => "2021-01-01,2021-01-02"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"date" => "2021-01-01", "visitors" => 2},
               %{"date" => "2021-01-02", "visitors" => 1}
             ]
           }
  end

  test "shows a custom range with monthly interval", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2020-12-01 00:00:00]),
      build(:pageview, user_id: @user_id, domain: site.domain, timestamp: ~N[2020-12-01 00:05:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-02 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "custom",
        "date" => "2020-12-01, 2021-01-02",
        "interval" => "month",
        "metrics" => "pageviews,visitors,bounce_rate,visit_duration"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{
                 "date" => "2020-12-01",
                 "visitors" => 1,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "visit_duration" => 300
               },
               %{
                 "date" => "2021-01-01",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 100,
                 "visit_duration" => 0
               }
             ]
           }
  end

  describe "filters" do
    test "can filter by source", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          referrer_source: "Google",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:source==Google"
        })

      res = json_response(conn, 200)
      assert List.first(res["results"]) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by no source/referrer", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          referrer_source: "Google",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:source==Direct / None"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by referrer", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          referrer: "https://facebook.com",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:referrer==https://facebook.com"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by utm_medium", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_medium: "social",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:utm_medium==social"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by utm_source", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_source: "Twitter",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:utm_source==Twitter"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by utm_campaign", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          utm_campaign: "profile",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:utm_campaign==profile"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by device type", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          screen_size: "Desktop",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:device==Desktop"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by browser", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          browser: "Chrome",
          browser_version: "56.1",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          browser: "Chrome",
          browser_version: "55",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:browser==Chrome;visit:browser_version==56.1"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by operating system", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.5",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Something else",
          operating_system_version: "10.5",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.4",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:os == Mac;visit:os_version==10.5"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by country", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          user_id: @user_id,
          country_code: "EE",
          operating_system_version: "10.5",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          country_code: "EE",
          operating_system_version: "10.5",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:country==EE",
          "metrics" => "visitors,pageviews,bounce_rate,visit_duration"
        })

      res = json_response(conn, 200)["results"]

      assert List.first(res) == %{
               "date" => "2021-01-01",
               "visitors" => 1,
               "pageviews" => 2,
               "bounce_rate" => 0,
               "visit_duration" => 900
             }
    end

    test "filtering by page - session metrics consider it like entry_page", %{
      conn: conn,
      site: site
    } do
      populate_stats([
        build(:pageview,
          pathname: "/hello",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/hello",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          pathname: "/hello",
          domain: site.domain,
          timestamp: ~N[2021-01-01 05:00:00]
        ),
        build(:pageview,
          pathname: "/goobye",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:page==/hello",
          "metrics" => "visitors,pageviews,bounce_rate,visit_duration"
        })

      res = json_response(conn, 200)["results"]

      assert List.first(res) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "pageviews" => 3,
               "bounce_rate" => 50,
               "visit_duration" => 150
             }
    end

    test "can filter by event:name", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Signup",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:name==Signup"
        })

      res = json_response(conn, 200)
      assert List.first(res["results"]) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "filter by custom event property", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["personal"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          domain: site.domain,
          timestamp: ~N[2021-01-02 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:name==Purchase;event:props:package==business"
        })

      %{"results" => [first, second | _rest]} = json_response(conn, 200)
      assert first == %{"date" => "2021-01-01", "visitors" => 2}
      assert second == %{"date" => "2021-01-02", "visitors" => 1}
    end
  end
end
