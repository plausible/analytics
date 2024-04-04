defmodule PlausibleWeb.Api.ExternalStatsController.TimeseriesTest do
  use PlausibleWeb.ConnCase
  alias Plausible.Billing.Feature

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

  describe "feature access" do
    test "cannot filter by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

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
      ep = insert(:enterprise_plan, features: [Feature.StatsAPI], user_id: user.id)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

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
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 23:59:00])
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
        get(conn, "/api/v1/stats/aggregate", %{
          "site_id" => site.domain,
          "filters" => "event:goal==Visit /register**"
        })

      assert %{"error" => msg} = json_response(conn, 400)

      assert msg =~
               "The pageview goal for the pathname `/register**` is not configured for this site"
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
          "date" => "2021-01-10"
        })

      assert [first, second | _] = json_response(conn, 200)["results"]

      assert [first, second] == [
               %{
                 "date" => "2021-01-04",
                 "conversion_rate" => 66.7
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
          "date" => "2021-01-10"
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
          "date" => "2021-01-10"
        })

      [first | _] = json_response(conn, 200)["results"]

      assert first == %{
               "date" => "2021-01-04",
               "conversion_rate" => 33.3
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
          "date" => "2021-01-10"
        })

      [first | _] = json_response(conn, 200)["results"]

      assert first == %{
               "date" => "2021-01-04",
               "conversion_rate" => 33.3
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
          "date" => "2021-01-07"
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
          "date" => "2021-01-07"
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
          "date" => "2021-01-07"
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
end
