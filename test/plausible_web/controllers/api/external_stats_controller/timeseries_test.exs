defmodule PlausibleWeb.Api.ExternalStatsController.TimeseriesTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test
  alias Plausible.Billing.Feature

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  describe "feature access" do
    test "cannot filter by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:props:author==Uku"
        })

      assert json_response(conn, 402)["error"] ==
               "The owner of this site does not have access to the custom properties feature"
    end

    test "can filter by an internal prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:props:path==/404"
        })

      assert json_response(conn, 200)["results"]
    end
  end

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

    test "ignores a given property parameter", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "property" => "event:props:author",
          "metrics" => "visit_duration"
        })

      assert json_response(conn, 200)
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

    test "legacy `date` interval is overridden to `day`", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "date" => "2021-06-30",
          "period" => "6mo",
          "interval" => "date"
        })

      results = json_response(conn, 200)["results"]

      assert Enum.at(results, 0)["date"] == "2021-01-01"
      assert Enum.at(results, 1)["date"] == "2021-01-02"
    end

    test "validates that interval is `day` or `month`", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "12mo",
          "interval" => "alskd"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `interval` parameter: invalid interval `alskd`. Valid intervals are `day`, `month`"
             }
    end
  end

  @user_id Enum.random(1000..9999)

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
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 02:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 03:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 04:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 05:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 06:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 07:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 08:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 09:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 10:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 11:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 12:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 13:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 14:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 15:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 16:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 17:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 18:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 19:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 20:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 21:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
               },
               %{
                 "date" => "2021-01-01 22:00:00",
                 "visitors" => 0,
                 "visits" => 0,
                 "pageviews" => 0,
                 "visit_duration" => nil,
                 "bounce_rate" => 0
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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
    ])

    conn =
      get(conn, "/api/v1/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "7d",
        "date" => "2021-01-08"
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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2020-02-01 00:00:00]),
      build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2020-02-01 00:00:00]),
      build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-02 00:00:00])
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
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-01 00:05:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-02 00:00:00])
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
    test "event:goal filter returns 400 when goal not configured", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,events",
          "filters" => "event:goal==Visit /register**"
        })

      assert %{"error" => msg} = json_response(conn, 400)

      assert msg =~
               "The pageview goal for the pathname `/register**` is not configured for this site"
    end

    test "validates that filters are valid", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,events",
          "filters" => "badproperty==bar"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Invalid filter property 'badproperty'. Please provide a valid filter property: https://plausible.io/docs/stats-api#properties"
             }
    end

    test "can filter by a custom event goal", %{conn: conn, site: site} do
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
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,events",
          "filters" => "event:goal==Signup"
        })

      res = json_response(conn, 200)

      assert List.first(res["results"]) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "events" => 3
             }
    end

    test "can filter by a simple pageview goal", %{conn: conn, site: site} do
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
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,pageviews",
          "filters" => "event:goal==Visit /register"
        })

      res = json_response(conn, 200)

      assert List.first(res["results"]) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "pageviews" => 3
             }
    end

    test "can filter by a wildcard pageview goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post-1", timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview,
          pathname: "/blog/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview, pathname: "/blog", user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:25:00])
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,pageviews",
          "filters" => "event:goal==Visit /blog**"
        })

      res = json_response(conn, 200)

      assert List.first(res["results"]) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "pageviews" => 3
             }
    end

    test "can filter by multiple custom event goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:25:00]),
        build(:event, name: "Purchase", user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:event, name: "Purchase", user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:25:00])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Purchase"})

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,events",
          "filters" => "event:goal==Signup|Purchase"
        })

      res = json_response(conn, 200)

      assert List.first(res["results"]) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "events" => 3
             }
    end

    test "can filter by multiple mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/account/register", timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview,
          pathname: "/register",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event, name: "Signup", user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:25:00])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/**register"})

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "metrics" => "visitors,events,pageviews",
          "filters" => "event:goal==Signup|Visit /**register"
        })

      res = json_response(conn, 200)

      assert List.first(res["results"]) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "events" => 3,
               "pageviews" => 2
             }
    end

    test "can filter by source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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

    test "can filter by channel", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Bing",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "visit:channel==Organic Search"
        })

      res = json_response(conn, 200)
      assert List.first(res["results"]) == %{"date" => "2021-01-01", "visitors" => 1}
    end

    test "can filter by no source/referrer", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview,
          referrer_source: "Google",
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
      populate_stats(site, [
        build(:pageview,
          referrer: "https://facebook.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          utm_medium: "social",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          utm_source: "Twitter",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          utm_campaign: "profile",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          browser: "Chrome",
          browser_version: "56.1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          browser: "Chrome",
          browser_version: "55",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.5",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Something else",
          operating_system_version: "10.5",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.4",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
          pathname: "/hello",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          pathname: "/hello",
          timestamp: ~N[2021-01-01 05:00:00]
        ),
        build(:pageview,
          pathname: "/goodbye",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:page==/hello",
          "metrics" => "visitors,visits,pageviews,bounce_rate,visit_duration"
        })

      res = json_response(conn, 200)["results"]

      assert List.first(res) == %{
               "date" => "2021-01-01",
               "visitors" => 2,
               "visits" => 2,
               "pageviews" => 2,
               "bounce_rate" => 100,
               "visit_duration" => 150
             }
    end

    test "can filter by hostname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          hostname: "landing.example.com",
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:pageview,
          user_id: @user_id,
          hostname: "example.com",
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        build(:pageview,
          user_id: @user_id,
          hostname: "example.com",
          timestamp: ~N[2021-01-01 00:00:06]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "filters" => "event:hostname==example.com",
          "metrics" => "visitors,visits,pageviews,bounce_rate,visit_duration"
        })

      res =
        json_response(conn, 200)["results"]

      assert List.first(res) == %{
               "bounce_rate" => 0,
               "date" => "2021-01-01 00:00:00",
               "pageviews" => 2,
               "visit_duration" => 5,
               "visitors" => 1,
               "visits" => 1
             }
    end

    test "can filter by event:name", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
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
          "meta.value": ["business"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["personal"],
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
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

    test "filter by multiple custom event properties", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["business", "Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["business", "Firefox"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["personal", "Firefox"],
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-02 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" =>
            "event:name==Purchase;event:props:package==business;event:props:browser==Firefox"
        })

      %{"results" => [first, second | _rest]} = json_response(conn, 200)
      assert first == %{"date" => "2021-01-01", "visitors" => 1}
      assert second == %{"date" => "2021-01-02", "visitors" => 0}
    end

    test "filter by multiple custom event properties matching", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["business", "Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["business", "Firefox"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package", "browser"],
          "meta.value": ["personal", "Safari"],
          timestamp: ~N[2021-01-02 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          timestamp: ~N[2021-01-02 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "month",
          "date" => "2021-01-01",
          "filters" => "event:name==Purchase;event:props:browser==F*|S*"
        })

      %{"results" => [first, second | _rest]} = json_response(conn, 200)
      assert first == %{"date" => "2021-01-01", "visitors" => 1}
      assert second == %{"date" => "2021-01-02", "visitors" => 1}
    end
  end

  describe "metrics" do
    test "returns conversion rate as 0 when no stats exist", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup",
          "period" => "7d",
          "date" => "2021-01-10"
        })

      Enum.each(json_response(conn, 200)["results"], fn bucket ->
        bucket["conversion_rate"] == 0.0
      end)
    end

    test "returns conversion rate when goal filter is applied", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup", timestamp: ~N[2021-01-04 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-04 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-04 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-05 00:00:00])
      ])

      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup",
          "period" => "7d",
          "date" => "2021-01-11"
        })

      assert [first, second | _] = json_response(conn, 200)["results"]

      assert [first, second] == [
               %{
                 "date" => "2021-01-04",
                 "conversion_rate" => 66.67
               },
               %{
                 "date" => "2021-01-05",
                 "conversion_rate" => 100.0
               }
             ]
    end

    test "returns conversion rate with a goal + custom prop filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          "meta.key": ["author"],
          "meta.value": ["Teet"],
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["author"],
          "meta.value": ["Tiit"],
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event, name: "Signup", timestamp: ~N[2021-01-04 00:12:00]),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Teet"],
          timestamp: ~N[2021-01-04 00:12:00]
        )
      ])

      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup;event:props:author==Teet",
          "period" => "7d",
          "date" => "2021-01-11"
        })

      [first | _] = json_response(conn, 200)["results"]

      assert first == %{
               "date" => "2021-01-04",
               "conversion_rate" => 25.0
             }
    end

    test "returns conversion rate with a goal + page filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          pathname: "/yes",
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/no",
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event, name: "Signup", timestamp: ~N[2021-01-04 00:12:00]),
        build(:pageview, pathname: "/yes", timestamp: ~N[2021-01-04 00:12:00]),
        build(:pageview, pathname: "/yes", timestamp: ~N[2021-01-04 00:12:00])
      ])

      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup;event:page==/yes",
          "period" => "7d",
          "date" => "2021-01-11"
        })

      [first | _] = json_response(conn, 200)["results"]

      assert first == %{
               "date" => "2021-01-04",
               "conversion_rate" => 33.33
             }
    end

    test "returns conversion rate with a goal + session filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          screen_size: "Mobile",
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event,
          name: "Signup",
          screen_size: "Laptop",
          timestamp: ~N[2021-01-04 00:12:00]
        ),
        build(:event, name: "Signup", timestamp: ~N[2021-01-04 00:12:00]),
        build(:pageview, screen_size: "Mobile", timestamp: ~N[2021-01-04 00:12:00]),
        build(:pageview, screen_size: "Mobile", timestamp: ~N[2021-01-04 00:12:00])
      ])

      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup;visit:device==Mobile",
          "period" => "7d",
          "date" => "2021-01-11"
        })

      [first | _] = json_response(conn, 200)["results"]

      assert first == %{
               "date" => "2021-01-04",
               "conversion_rate" => 33.33
             }
    end

    test "validates that conversion_rate cannot be queried without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "metrics" => "conversion_rate"
        })

      assert %{"error" => msg} = json_response(conn, 400)

      assert msg ==
               "Metric `conversion_rate` can only be queried in a goal breakdown or with a goal filter"
    end

    test "shows pageviews,visits,views_per_visit for last 7d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "pageviews,visits,views_per_visit",
          "date" => "2021-01-08"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "date" => "2021-01-01",
                   "pageviews" => 3,
                   "visits" => 2,
                   "views_per_visit" => 1.5
                 },
                 %{
                   "date" => "2021-01-02",
                   "pageviews" => 0,
                   "visits" => 0,
                   "views_per_visit" => 0.0
                 },
                 %{
                   "date" => "2021-01-03",
                   "pageviews" => 0,
                   "visits" => 0,
                   "views_per_visit" => 0.0
                 },
                 %{
                   "date" => "2021-01-04",
                   "pageviews" => 0,
                   "visits" => 0,
                   "views_per_visit" => 0.0
                 },
                 %{
                   "date" => "2021-01-05",
                   "pageviews" => 0,
                   "visits" => 0,
                   "views_per_visit" => 0.0
                 },
                 %{
                   "date" => "2021-01-06",
                   "pageviews" => 0,
                   "visits" => 0,
                   "views_per_visit" => 0.0
                 },
                 %{
                   "date" => "2021-01-07",
                   "pageviews" => 1,
                   "visits" => 1,
                   "views_per_visit" => 1.0
                 }
               ]
             }
    end

    test "shows events for last 7d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "events",
          "date" => "2021-01-08"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "date" => "2021-01-01",
                   "events" => 2
                 },
                 %{
                   "date" => "2021-01-02",
                   "events" => 0
                 },
                 %{
                   "date" => "2021-01-03",
                   "events" => 0
                 },
                 %{
                   "date" => "2021-01-04",
                   "events" => 0
                 },
                 %{
                   "date" => "2021-01-05",
                   "events" => 0
                 },
                 %{
                   "date" => "2021-01-06",
                   "events" => 0
                 },
                 %{
                   "date" => "2021-01-07",
                   "events" => 1
                 }
               ]
             }
    end

    test "rounds views_per_visit to two decimal places", %{
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
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-03 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-03 00:01:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
      ])

      conn =
        get(conn, "/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "views_per_visit",
          "date" => "2021-01-08"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"date" => "2021-01-01", "views_per_visit" => 2.0},
                 %{"date" => "2021-01-02", "views_per_visit" => 0.0},
                 %{"date" => "2021-01-03", "views_per_visit" => 1.33},
                 %{"date" => "2021-01-04", "views_per_visit" => 0.0},
                 %{"date" => "2021-01-05", "views_per_visit" => 0.0},
                 %{"date" => "2021-01-06", "views_per_visit" => 0.0},
                 %{"date" => "2021-01-07", "views_per_visit" => 1.0}
               ]
             }
    end
  end

  describe "imported data" do
    test "returns pageviews as the value of events metric", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_visitors, pageviews: 1, date: ~D[2021-01-01])
      ])

      conn =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "events",
          "date" => "2021-01-08",
          "with_imported" => "true"
        })

      first_result =
        conn
        |> json_response(200)
        |> Map.get("results")
        |> List.first()

      assert first_result == %{"date" => "2021-01-01", "events" => 1}

      refute json_response(conn, 200)["warning"]
    end

    test "adds a warning when query params are not supported for imported data", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["large"],
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:imported_visitors, pageviews: 1, date: ~D[2021-01-01])
      ])

      conn =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "events",
          "date" => "2021-01-08",
          "with_imported" => "true",
          "filters" => "event:props:package==large"
        })

      first_result =
        conn
        |> json_response(200)
        |> Map.get("results")
        |> List.first()

      assert first_result == %{"date" => "2021-01-01", "events" => 1}

      assert json_response(conn, 200)["warning"] =~
               "Imported stats are not included in the results because query parameters are not supported."
    end

    test "is not included for a day period and an appropriate warning is returned", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_visitors, visitors: 1, date: ~D[2021-01-01])
      ])

      conn =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "day",
          "metrics" => "visitors",
          "date" => "2021-01-01",
          "with_imported" => "true"
        })

      assert %{"results" => results, "warning" => warning} = json_response(conn, 200)

      Enum.each(results, &assert(&1["visitors"] == 0))

      assert warning ==
               "Imported stats are not included because the time dimension (i.e. the interval) is too short."
    end

    test "does not add a warning when there are no site imports", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["large"],
          timestamp: ~N[2021-01-01 12:00:00]
        )
      ])

      conn =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "events",
          "date" => "2021-01-07",
          "with_imported" => "true",
          "filters" => "event:props:package==large"
        })

      refute json_response(conn, 200)["warning"]
    end

    test "does not add a warning when import is out of queried date range", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site, end_date: ~D[2020-12-29])

      populate_stats(site, site_import.id, [
        build(:pageview,
          "meta.key": ["package"],
          "meta.value": ["large"],
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:imported_visitors, pageviews: 1, date: ~D[2020-12-29])
      ])

      conn =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "7d",
          "metrics" => "events",
          "date" => "2021-01-07",
          "with_imported" => "true",
          "filters" => "event:props:package==large"
        })

      refute json_response(conn, 200)["warning"]
    end

    test "returns all metrics based on imported/native data when filtering by browser", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, browser: "Chrome", user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, browser: "Chrome", user_id: 1, timestamp: ~N[2021-01-01 00:03:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_browsers, browser: "Firefox", date: ~D[2021-01-02]),
        build(:imported_browsers,
          browser: "Chrome",
          visitors: 1,
          pageviews: 1,
          bounces: 1,
          visit_duration: 3,
          visits: 1,
          date: ~D[2021-01-03]
        ),
        build(:pageview, browser: "Chrome", user_id: 2, timestamp: ~N[2021-01-04 00:00:00]),
        build(:event,
          name: "Signup",
          browser: "Chrome",
          user_id: 2,
          timestamp: ~N[2021-01-04 00:10:00]
        ),
        build(:imported_browsers,
          browser: "Chrome",
          visitors: 4,
          pageviews: 6,
          bounces: 1,
          visit_duration: 300,
          visits: 5,
          date: ~D[2021-01-04]
        )
      ])

      results =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2021-01-01,2021-01-04",
          "metrics" =>
            "visitors,pageviews,events,visits,views_per_visit,bounce_rate,visit_duration",
          "filters" => "visit:browser==Chrome",
          "with_imported" => "true"
        })
        |> json_response(200)
        |> Map.get("results")

      assert results == [
               %{
                 "bounce_rate" => 0.0,
                 "date" => "2021-01-01",
                 "events" => 2,
                 "pageviews" => 2,
                 "views_per_visit" => 2.0,
                 "visit_duration" => 180.0,
                 "visitors" => 1,
                 "visits" => 1
               },
               %{
                 "bounce_rate" => 0,
                 "date" => "2021-01-02",
                 "events" => 0,
                 "pageviews" => 0,
                 "views_per_visit" => 0.0,
                 "visit_duration" => nil,
                 "visitors" => 0,
                 "visits" => 0
               },
               %{
                 "bounce_rate" => 100,
                 "date" => "2021-01-03",
                 "events" => 1,
                 "pageviews" => 1,
                 "views_per_visit" => 1.0,
                 "visit_duration" => 3,
                 "visitors" => 1,
                 "visits" => 1
               },
               %{
                 "bounce_rate" => 17.0,
                 "date" => "2021-01-04",
                 "events" => 8,
                 "pageviews" => 7,
                 "views_per_visit" => 1.17,
                 "visit_duration" => 150,
                 "visitors" => 5,
                 "visits" => 6
               }
             ]
    end

    test "returns conversion rate timeseries with a goal filter", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      insert(:goal, site: site, event_name: "Outbound Link: Click")

      populate_stats(site, site_import.id, [
        # 2021-01-01
        build(:event, name: "Outbound Link: Click", timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_custom_events, name: "Outbound Link: Click", date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 4),
        # 2021-01-02
        build(:event, name: "Outbound Link: Click", timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        # 2021-01-03
        build(:imported_custom_events, name: "Outbound Link: Click", date: ~D[2021-01-03]),
        build(:imported_visitors, date: ~D[2021-01-03]),
        # 2021-01-04
        build(:event, name: "Outbound Link: Click", timestamp: ~N[2021-01-04 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-04], visitors: 2)
      ])

      results =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2021-01-01,2021-01-04",
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Outbound Link: Click",
          "with_imported" => "true"
        })
        |> json_response(200)
        |> Map.get("results")

      assert results == [
               %{
                 "date" => "2021-01-01",
                 "conversion_rate" => 40.0
               },
               %{
                 "date" => "2021-01-02",
                 "conversion_rate" => 50.0
               },
               %{
                 "date" => "2021-01-03",
                 "conversion_rate" => 100.0
               },
               %{
                 "date" => "2021-01-04",
                 "conversion_rate" => 33.33
               }
             ]
    end

    test "ignores imported data in conversion rate total calculation when imported data cannot be included",
         %{
           conn: conn,
           site: site
         } do
      site_import = insert(:site_import, site: site)

      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, site_import.id, [
        build(:event, name: "Signup", pathname: "/register", timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_custom_events, name: "Signup", date: ~D[2021-01-01], visitors: 1),
        build(:imported_pages, page: "/register", date: ~D[2021-01-01], visitors: 2)
      ])

      %{"results" => results, "warning" => warning} =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2021-01-01,2021-01-01",
          "interval" => "day",
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Signup;event:page==/register",
          "with_imported" => "true"
        })
        |> json_response(200)

      assert results == [
               %{
                 "date" => "2021-01-01",
                 "conversion_rate" => 100.0
               }
             ]

      assert warning =~ "Imported stats are not included in the results"
    end

    test "returns conversion rate timeseries with a goal + custom prop filter", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      insert(:goal, site: site, event_name: "Outbound Link: Click")

      populate_stats(site, site_import.id, [
        # 2021-01-01
        build(:event,
          name: "Outbound Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://site.com"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://site.com",
          date: ~D[2021-01-01]
        ),
        build(:imported_custom_events,
          name: "File Download",
          link_url: "https://site.com",
          date: ~D[2021-01-01]
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://notthis.com",
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 4),
        # 2021-01-03
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://site.com",
          date: ~D[2021-01-03]
        ),
        build(:imported_visitors, date: ~D[2021-01-03]),
        # 2021-01-04
        build(:event,
          name: "Outbound Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://site.com"],
          timestamp: ~N[2021-01-04 00:00:00]
        ),
        build(:imported_visitors, date: ~D[2021-01-04], visitors: 2)
      ])

      results =
        conn
        |> get("/api/v1/stats/timeseries", %{
          "site_id" => site.domain,
          "period" => "custom",
          "date" => "2021-01-01,2021-01-04",
          "metrics" => "conversion_rate",
          "filters" => "event:goal==Outbound Link: Click;event:props:url==https://site.com",
          "with_imported" => "true"
        })
        |> json_response(200)
        |> Map.get("results")

      assert results == [
               %{
                 "date" => "2021-01-01",
                 "conversion_rate" => 40.0
               },
               %{
                 "date" => "2021-01-02",
                 "conversion_rate" => 0.0
               },
               %{
                 "date" => "2021-01-03",
                 "conversion_rate" => 100.0
               },
               %{
                 "date" => "2021-01-04",
                 "conversion_rate" => 33.33
               }
             ]
    end
  end
end
