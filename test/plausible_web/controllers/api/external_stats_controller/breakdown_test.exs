defmodule PlausibleWeb.Api.ExternalStatsController.BreakdownTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id 1231

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

  describe "param validation" do
    test "validates that property is required", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "The `property` parameter is required. Please provide at least one property to show a breakdown by."
             }
    end

    test "validates that correct period is used", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "bad_period"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Error parsing `period` parameter: invalid period `bad_period`. Please find accepted values in our docs: https://plausible.io/docs/stats-api#time-periods"
             }
    end

    test "fails when an invalid metric is provided", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "property" => "event:page",
          "metrics" => "visitors,baa",
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "The metric `baa` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#get-apiv1statsbreakdown"
             }
    end

    test "session metrics cannot be used with event:name property", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "property" => "event:name",
          "metrics" => "visitors,bounce_rate",
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Session metric `bounce_rate` cannot be queried for breakdown by `event:name`."
             }
    end

    test "session metrics cannot be used with event:name filter", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "property" => "event:page",
          "filters" => "event:name==Signup",
          "metrics" => "visitors,bounce_rate",
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Session metric `bounce_rate` cannot be queried when using a filter on `event:name`."
             }
    end
  end

  test "breakdown by visit:source", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        referrer_source: "Google",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer_source: "Google",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        referrer_source: "",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:source"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"source" => "Google", "visitors" => 2},
               %{"source" => "Direct / None", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:country", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, country_code: "EE", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, country_code: "EE", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, country_code: "US", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:country"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"country" => "EE", "visitors" => 2},
               %{"country" => "US", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:referrer", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        referrer: "https://ref.com",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        referrer: "https://ref.com",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        referrer: "",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:referrer"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"referrer" => "https://ref.com", "visitors" => 2},
               %{"referrer" => "Direct / None", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:utm_medium", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        utm_medium: "Search",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        utm_medium: "Search",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        utm_medium: "",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:utm_medium"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"utm_medium" => "Search", "visitors" => 2},
               %{"utm_medium" => "Direct / None", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:utm_source", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        utm_source: "Google",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        utm_source: "Google",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        utm_source: "",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:utm_source"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"utm_source" => "Google", "visitors" => 2},
               %{"utm_source" => "Direct / None", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:utm_campaign", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        utm_campaign: "ads",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        utm_campaign: "ads",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        utm_campaign: "",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:utm_campaign"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"utm_campaign" => "ads", "visitors" => 2},
               %{"utm_campaign" => "Direct / None", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:device", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        screen_size: "Desktop",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        screen_size: "Desktop",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        screen_size: "Mobile",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:device"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"device" => "Desktop", "visitors" => 2},
               %{"device" => "Mobile", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:os", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        operating_system: "Mac",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        operating_system: "Mac",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        operating_system: "Windows",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:os"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"os" => "Mac", "visitors" => 2},
               %{"os" => "Windows", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:os_version", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        operating_system_version: "10.5",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        operating_system_version: "10.5",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        operating_system_version: "10.6",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:os_version"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"os_version" => "10.5", "visitors" => 2},
               %{"os_version" => "10.6", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:browser", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, browser: "Firefox", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Firefox", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, browser: "Safari", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:browser"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"browser" => "Firefox", "visitors" => 2},
               %{"browser" => "Safari", "visitors" => 1}
             ]
           }
  end

  test "breakdown by visit:browser_version", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview,
        browser_version: "56",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        browser_version: "56",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        browser_version: "57",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:browser_version"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"browser_version" => "56", "visitors" => 2},
               %{"browser_version" => "57", "visitors" => 1}
             ]
           }
  end

  test "breakdown by event:page", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, pathname: "/", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, pathname: "/", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview,
        pathname: "/plausible.io",
        domain: site.domain,
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "event:page"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"page" => "/", "visitors" => 2},
               %{"page" => "/plausible.io", "visitors" => 1}
             ]
           }
  end

  describe "custom events" do
    test "can breakdown by event:name", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Signup",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:name"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"name" => "Signup", "visitors" => 2},
                 %{"name" => "pageview", "visitors" => 1}
               ]
             }
    end

    test "can breakdown by event:name while filtering for something", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          browser: "Safari",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageB",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:name",
          "filters" => "event:page==/pageA;visit:browser==Chrome"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"name" => "Signup", "visitors" => 2},
                 %{"name" => "pageview", "visitors" => 1}
               ]
             }
    end

    test "can breakdown by a visit:property when filtering by event:name", %{
      conn: conn,
      site: site
    } do
      populate_stats([
        build(:pageview,
          referrer_source: "Google",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          domain: site.domain,
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:source",
          "filters" => "event:name==Signup"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"source" => "Google", "visitors" => 1}
               ]
             }
    end

    test "can breakdown by event:name when filtering by event:page", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          pathname: "/pageA",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          pathname: "/pageA",
          name: "Signup",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          domain: site.domain,
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:name",
          "filters" => "event:page==/pageA"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"name" => "pageview", "visitors" => 2},
                 %{"name" => "Signup", "visitors" => 1}
               ]
             }
    end

    test "can breakdown by event:page when filtering by event:name", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageB",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          domain: site.domain,
          referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "filters" => "event:name==Signup"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/pageA", "visitors" => 2},
                 %{"page" => "/pageB", "visitors" => 1}
               ]
             }
    end

    test "breakdown by custom event property", %{conn: conn, site: site} do
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
          "meta.value": ["personal"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Some other event",
          "meta.key": ["package"],
          "meta.value": ["business"],
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:props:package",
          "filters" => "event:name==Purchase"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"package" => "business", "visitors" => 2},
                 %{"package" => "personal", "visitors" => 1}
               ]
             }
    end
  end

  describe "filtering" do
    test "event:page filter for breakdown by session props", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          pathname: "/ignore",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          browser: "Safari",
          pathname: "/plausible.io",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:browser",
          "filters" => "event:page==/plausible.io"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Chrome", "visitors" => 2},
                 %{"browser" => "Safari", "visitors" => 1}
               ]
             }
    end
  end

  describe "pagination" do
    test "can limit results", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview, pathname: "/a", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/b", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, pathname: "/c", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "limit" => 2
        })

      res = json_response(conn, 200)
      assert Enum.count(res["results"]) == 2
    end

    test "can paginate results", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview, pathname: "/a", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/b", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, pathname: "/c", domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "limit" => 2,
          "page" => 2
        })

      res = json_response(conn, 200)
      assert Enum.count(res["results"]) == 1
    end
  end

  describe "metrics" do
    test "all metrics for breakdown by visit prop", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          referrer_source: "Google",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          referrer_source: "Twitter",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:source",
          "metrics" => "visitors,pageviews,bounce_rate,visit_duration"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "source" => "Google",
                   "visitors" => 2,
                   "bounce_rate" => 50,
                   "visit_duration" => 300,
                   "pageviews" => 3
                 },
                 %{
                   "source" => "Twitter",
                   "visitors" => 1,
                   "bounce_rate" => 100,
                   "visit_duration" => 0,
                   "pageviews" => 1
                 }
               ]
             }
    end

    test "filter by custom event property", %{conn: conn, site: site} do
      populate_stats([
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          browser: "Chrome",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          browser: "Safari",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          browser: "Safari",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["personal"],
          browser: "IE",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:25:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:browser",
          "filters" => "event:name==Purchase;event:props:package==business"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Safari", "visitors" => 2},
                 %{"browser" => "Chrome", "visitors" => 1}
               ]
             }
    end

    test "all metrics for breakdown by event prop", %{conn: conn, site: site} do
      populate_stats([
        build(:pageview,
          user_id: 1,
          pathname: "/",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/plausible.io",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview, pathname: "/", domain: site.domain, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview,
          pathname: "/plausible.io",
          domain: site.domain,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "metrics" => "visitors,pageviews,bounce_rate,visit_duration"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/",
                   "visitors" => 2,
                   "bounce_rate" => 50,
                   "visit_duration" => 300,
                   "pageviews" => 2
                 },
                 %{
                   "page" => "/plausible.io",
                   "visitors" => 2,
                   "bounce_rate" => 100,
                   "visit_duration" => 0,
                   "pageviews" => 2
                 }
               ]
             }
    end
  end
end
