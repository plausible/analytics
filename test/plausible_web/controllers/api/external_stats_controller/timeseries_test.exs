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
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-02 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "custom",
        "date" => "2020-12-01, 2021-01-02",
        "interval" => "month"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"date" => "2020-12-01", "visitors" => 1},
               %{"date" => "2021-01-01", "visitors" => 2}
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
          country_code: "EE",
          operating_system_version: "10.5",
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
          "filters" => "visit:country==EE"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by page", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          pathname: "/hello",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/hello",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
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
          "filters" => "event:page==/hello"
        })

      res = json_response(conn, 200)["results"]
      assert List.first(res) == %{"date" => "2021-01-01", "visitors" => 2}
    end
  end
end
