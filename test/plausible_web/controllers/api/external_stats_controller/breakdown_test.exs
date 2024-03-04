defmodule PlausibleWeb.Api.ExternalStatsController.BreakdownTest do
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:props:author"
        })

      assert json_response(conn, 402)["error"] ==
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:props:path"
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "visit:source",
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "visit:source",
          "filters" => "event:props:url==whatever"
        })

      assert json_response(conn, 200)["results"]
    end
  end

  describe "param validation" do
    test "time_on_page is not supported in breakdown queries other than by event:page", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "visit:source",
          "filters" => "event:page==/A",
          "metrics" => "time_on_page"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Metric `time_on_page` is not supported in breakdown queries (except `event:page` breakdown)"
             }
    end

    test "does not allow querying conversion_rate without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:page",
          "metrics" => "conversion_rate"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Metric `conversion_rate` can only be queried in a goal breakdown or with a goal filter"
             }
    end

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

    test "validates that property is valid", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "badproperty"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Invalid property 'badproperty'. Please provide a valid property for the breakdown endpoint: https://plausible.io/docs/stats-api#properties"
             }
    end

    test "empty custom prop is invalid", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:props:"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Invalid property 'event:props:'. Please provide a valid property for the breakdown endpoint: https://plausible.io/docs/stats-api#properties"
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
                 "The metric `baa` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#metrics"
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

    test "session metrics cannot be used with event:props:* property", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "property" => "event:props:url",
          "metrics" => "visitors,bounce_rate",
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Session metric `bounce_rate` cannot be queried for breakdown by `event:props:url`."
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

    test "session metrics cannot be used with event:props:* filter", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "property" => "event:page",
          "filters" => "event:props:url==google.com",
          "metrics" => "visitors,bounce_rate",
          "site_id" => site.domain
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Session metric `bounce_rate` cannot be queried when using a filter on `event:props:url`."
             }
    end
  end

  test "breakdown by visit:source", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_referrer_source: "Google",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_referrer_source: "",
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
    populate_stats(site, [
      build(:pageview, session_country_code: "EE", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, session_country_code: "EE", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, session_country_code: "US", timestamp: ~N[2021-01-01 00:00:00])
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
    populate_stats(site, [
      build(:pageview,
        session_referrer: "https://ref.com",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_referrer: "https://ref.com",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_referrer: "",
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
    populate_stats(site, [
      build(:pageview,
        session_utm_medium: "Search",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_utm_medium: "Search",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_utm_medium: "",
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
               %{"utm_medium" => "Search", "visitors" => 2}
             ]
           }
  end

  test "breakdown by visit:utm_source", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_utm_source: "Google",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_utm_source: "Google",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_utm_source: "",
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
               %{"utm_source" => "Google", "visitors" => 2}
             ]
           }
  end

  test "breakdown by visit:utm_campaign", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_utm_campaign: "ads",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_utm_campaign: "ads",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_utm_campaign: "",
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
               %{"utm_campaign" => "ads", "visitors" => 2}
             ]
           }
  end

  test "breakdown by visit:utm_content", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_utm_content: "Content1",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_utm_content: "Content1",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_utm_content: "",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:utm_content"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"utm_content" => "Content1", "visitors" => 2}
             ]
           }
  end

  test "breakdown by visit:utm_term", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_utm_term: "Term1",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_utm_term: "Term1",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_utm_term: "",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "visit:utm_term"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"utm_term" => "Term1", "visitors" => 2}
             ]
           }
  end

  test "breakdown by visit:device", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview,
        session_screen_size: "Desktop",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_screen_size: "Desktop",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_screen_size: "Mobile",
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
    populate_stats(site, [
      build(:pageview,
        session_operating_system: "Mac",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_operating_system: "Mac",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_operating_system: "Windows",
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
    populate_stats(site, [
      build(:pageview, session_operating_system: "Mac", session_operating_system_version: "14"),
      build(:pageview, session_operating_system: "Mac", session_operating_system_version: "14"),
      build(:pageview, session_operating_system: "Mac", session_operating_system_version: "14"),
      build(:pageview, session_operating_system_version: "14"),
      build(:pageview,
        session_operating_system: "Windows",
        session_operating_system_version: "11"
      ),
      build(:pageview,
        session_operating_system: "Windows",
        session_operating_system_version: "11"
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "property" => "visit:os_version"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"os_version" => "14", "visitors" => 3, "os" => "Mac"},
               %{"os_version" => "11", "visitors" => 2, "os" => "Windows"},
               %{"os_version" => "14", "visitors" => 1, "os" => "(not set)"}
             ]
           }
  end

  test "breakdown by visit:browser", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, session_browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, session_browser: "Firefox", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, session_browser: "Safari", timestamp: ~N[2021-01-01 00:00:00])
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
    populate_stats(site, [
      build(:pageview,
        session_browser_version: "56",
        timestamp: ~N[2021-01-01 00:00:00]
      ),
      build(:pageview,
        session_browser_version: "56",
        timestamp: ~N[2021-01-01 00:25:00]
      ),
      build(:pageview,
        session_browser_version: "57",
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
               %{"browser_version" => "56", "visitors" => 2, "browser" => "(not set)"},
               %{"browser_version" => "57", "visitors" => 1, "browser" => "(not set)"}
             ]
           }
  end

  test "pageviews breakdown by event:page - imported data having pageviews=0 and visitors=n should be bypassed",
       %{conn: conn, site: site} do
    site =
      site
      |> Plausible.Site.start_import(~D[2005-01-01], Timex.today(), "Google Analytics", "ok")
      |> Plausible.Repo.update!()

    populate_stats(site, [
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
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "event:page",
        "with_imported" => "true",
        "metrics" => "pageviews"
      })

    assert json_response(conn, 200) == %{
             "results" => [
               %{"page" => "/", "pageviews" => 2},
               %{"page" => "/plausible.io", "pageviews" => 1},
               %{"page" => "/include-me", "pageviews" => 1}
             ]
           }
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

  test "breakdown by event:page when there are no events in the second page", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, pathname: "/", timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview,
        pathname: "/plausible.io",
        timestamp: ~N[2021-01-01 00:00:00]
      )
    ])

    conn =
      get(conn, "/api/v1/stats/breakdown", %{
        "site_id" => site.domain,
        "period" => "day",
        "date" => "2021-01-01",
        "property" => "event:page",
        "metrics" => "visitors,bounce_rate",
        "page" => 2,
        "limit" => 2
      })

    assert json_response(conn, 200) == %{"results" => []}
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:name",
          "metrics" => "visitors,events"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"name" => "pageview", "visitors" => 2, "events" => 4},
                 %{"name" => "404", "visitors" => 1, "events" => 2}
               ]
             }
    end

    test "can breakdown by event:name while filtering for something", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageA",
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/pageB",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          session_browser: "Chrome",
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
      populate_stats(site, [
        build(:pageview,
          session_referrer_source: "Google",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_referrer_source: "Twitter",
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
          session_referrer_source: "Twitter",
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:page",
          "filters" => "event:page==/en/**"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/en/page2", "visitors" => 2},
                 %{"page" => "/en/page1", "visitors" => 1}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:props:cost",
          "filters" => "event:name==Purchase"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"cost" => "16", "visitors" => 3},
                 %{"cost" => "14", "visitors" => 2},
                 %{"cost" => "(none)", "visitors" => 1}
               ]
             }
    end

    test "breakdown by custom event property, limited", %{conn: conn, site: site} do
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
          "meta.value": ["18"],
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:props:cost",
          "filters" => "event:name==Purchase",
          "limit" => 2
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"cost" => "14", "visitors" => 2},
                 %{"cost" => "16", "visitors" => 1}
               ]
             }
    end

    test "breakdown by custom event property, paginated", %{conn: conn, site: site} do
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
          "meta.value": ["18"],
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:props:cost",
          "filters" => "event:name==Purchase",
          "limit" => 2,
          "page" => 2
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"cost" => "18", "visitors" => 1}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:goal"
        })

      assert [
               %{"goal" => "Purchase", "visitors" => 2},
               %{"goal" => "Visit /test", "visitors" => 1}
             ] = json_response(conn, 200)["results"]
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "metrics" => "visitors,pageviews",
          "property" => "event:goal"
        })

      assert [
               %{"goal" => "Visit /**/post", "visitors" => 2, "pageviews" => 2},
               %{"goal" => "Visit /blog**", "visitors" => 2, "pageviews" => 4}
             ] = json_response(conn, 200)["results"]
    end

    test "does not return goals that are not configured for the site", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup")
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "metrics" => "visitors,pageviews",
          "property" => "event:goal"
        })

      assert [] = json_response(conn, 200)["results"]
    end
  end

  describe "filtering" do
    test "event:goal filter returns 400 when goal not configured", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:page",
          "filters" => "event:goal==Register"
        })

      assert %{"error" => msg} = json_response(conn, 400)
      assert msg =~ "The goal `Register` is not configured for this site. Find out how"
    end

    test "event:page filter for breakdown by session props", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/ignore",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          session_browser: "Safari",
          pathname: "/plausible.io",
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

    test "event:page filter shows sources of sessions that have visited that page", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          session_referrer_source: "Twitter",
          session_utm_medium: "Twitter",
          session_utm_source: "Twitter",
          session_utm_campaign: "Twitter",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/plausible.io",
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_referrer_source: "Google",
          session_utm_medium: "Google",
          session_utm_source: "Google",
          session_utm_campaign: "Google"
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_referrer_source: "Google",
          session_utm_medium: "Google",
          session_utm_source: "Google",
          session_utm_campaign: "Google"
        )
      ])

      for property <- ["source", "utm_medium", "utm_source", "utm_campaign"] do
        conn =
          get(conn, "/api/v1/stats/breakdown", %{
            "site_id" => site.domain,
            "period" => "day",
            "property" => "visit:" <> property,
            "filters" => "event:page==/plausible.io"
          })

        assert json_response(conn, 200) == %{
                 "results" => [
                   %{property => "Google", "visitors" => 2},
                   %{property => "Twitter", "visitors" => 1}
                 ]
               }
      end
    end

    test "event:page filter is interpreted as entry_page filter only for bounce_rate", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          session_browser: "Chrome",
          user_id: @user_id,
          pathname: "/ignore",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          user_id: @user_id,
          pathname: "/plausible.io",
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          user_id: 456,
          pathname: "/important-page",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          user_id: 456,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          pathname: "/plausible.io",
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "metrics" => "visitors,bounce_rate",
          "property" => "visit:browser",
          "filters" => "event:page == /plausible.io|/important-page"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "browser" => "Chrome",
                   "bounce_rate" => 50,
                   "visitors" => 3
                 }
               ]
             }
    end

    test "event:goal pageview filter for breakdown by visit source", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/plausible.io"})

      populate_stats(site, [
        build(:pageview,
          session_referrer_source: "Bing",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_referrer_source: "Google",
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:source",
          "filters" => "event:goal == Visit /plausible.io"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"source" => "Google", "visitors" => 1}
               ]
             }
    end

    test "event:goal custom event filter for breakdown by visit source", %{conn: conn, site: site} do
      insert(:goal, %{site: site, event_name: "Register"})

      populate_stats(site, [
        build(:pageview,
          session_referrer_source: "Bing",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_referrer_source: "Google",
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:source",
          "filters" => "event:goal == Register"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"source" => "Google", "visitors" => 1}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "metrics" => "visitors,pageviews",
          "property" => "event:page",
          "filters" => "event:goal==Visit /**register"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/en/register", "visitors" => 2, "pageviews" => 3},
                 %{"page" => "/123/it/register", "visitors" => 1, "pageviews" => 1}
               ]
             }
    end

    test "mixed multi-goal filter for breakdown by visit:country", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, session_country_code: "EE", pathname: "/en/register"),
        build(:event, session_country_code: "EE", name: "Signup", pathname: "/en/register"),
        build(:pageview, session_country_code: "US", pathname: "/123/it/register"),
        build(:pageview, session_country_code: "US", pathname: "/different")
      ])

      insert(:goal, %{site: site, page_path: "/**register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "metrics" => "visitors,pageviews,events",
          "property" => "visit:country",
          "filters" => "event:goal==Signup|Visit /**register"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"country" => "EE", "visitors" => 2, "pageviews" => 1, "events" => 2},
                 %{"country" => "US", "visitors" => 1, "pageviews" => 1, "events" => 1}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "filters" => "event:page == /plausible.io|/important-page"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/plausible.io", "visitors" => 2},
                 %{"page" => "/important-page", "visitors" => 1}
               ]
             }
    end

    test "IN filter for visit:browser", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/ignore",
          session_browser: "Firefox",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/plausible.io",
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/important-page",
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "filters" => "visit:browser == Chrome|Safari"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/plausible.io", "visitors" => 2},
                 %{"page" => "/important-page", "visitors" => 1}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "filters" => "event:page == /plausible.io|/important-page",
          "metrics" => "bounce_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"page" => "/plausible.io", "bounce_rate" => 100},
                 %{"page" => "/important-page", "bounce_rate" => 100}
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:name",
          "filters" => "event:name == Signup|Login"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"name" => "Signup", "visitors" => 2},
                 %{"name" => "Login", "visitors" => 1}
               ]
             }
    end

    test "IN filter for event:props:*", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Safari",
          "meta.key": ["browser"],
          "meta.value": ["Safari"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Firefox",
          "meta.key": ["browser"],
          "meta.value": ["Firefox"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:browser",
          "filters" => "event:props:browser == Chrome|Safari"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Chrome", "visitors" => 2},
                 %{"browser" => "Safari", "visitors" => 1}
               ]
             }
    end

    test "Multiple event:props:* filters", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser", "prop"],
          "meta.value": ["Chrome", "xyz"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Safari",
          "meta.key": ["browser", "prop"],
          "meta.value": ["Safari", "target_value"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Firefox",
          "meta.key": ["browser", "prop"],
          "meta.value": ["Firefox", "target_value"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:browser",
          "filters" => "event:props:browser == Chrome|Safari;event:props:prop == target_value"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Safari", "visitors" => 1}
               ]
             }
    end

    test "IN filter for event:props:* including (none) value", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          session_browser: "Firefox",
          "meta.key": ["browser"],
          "meta.value": ["Firefox"],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:browser",
          "filters" => "event:props:browser == Chrome|(none)"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Chrome", "visitors" => 2},
                 %{"browser" => "Safari", "visitors" => 1}
               ]
             }
    end

    test "can use a is_not filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, session_browser: "Chrome"),
        build(:pageview, session_browser: "Safari"),
        build(:pageview, session_browser: "Safari"),
        build(:pageview, session_browser: "Edge")
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "filters" => "visit:browser != Chrome",
          "property" => "visit:browser"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{"browser" => "Safari", "visitors" => 2},
                 %{"browser" => "Edge", "visitors" => 1}
               ]
             }
    end
  end

  describe "pagination" do
    test "can limit results", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/a", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/b", timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, pathname: "/c", timestamp: ~N[2021-01-01 00:00:00])
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

    test "does not repeat results", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, %{"meta.key": ["item"], "meta.value": ["apple"]}),
        build(:pageview, %{"meta.key": ["item"], "meta.value": ["kiwi"]}),
        build(:pageview, %{"meta.key": ["item"], "meta.value": ["pineapple"]}),
        build(:pageview, %{"meta.key": ["item"], "meta.value": ["grapes"]})
      ])

      params = %{
        "site_id" => site.domain,
        "metrics" => "visitors",
        "property" => "event:props:item",
        "limit" => 3,
        "page" => nil
      }

      first_page =
        conn
        |> get("/api/v1/stats/breakdown", %{params | "page" => 1})
        |> json_response(200)
        |> Map.get("results")
        |> Enum.map(& &1["item"])
        |> MapSet.new()

      second_page =
        conn
        |> get("/api/v1/stats/breakdown", %{params | "page" => 2})
        |> json_response(200)
        |> Map.get("results")
        |> Enum.map(& &1["item"])
        |> MapSet.new()

      assert first_page |> MapSet.intersection(second_page) |> Enum.empty?()
    end

    @invalid_limit_message "Please provide limit as a number between 1 and 1000."

    test "returns error when limit too large", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:page",
          "limit" => 1001
        })

      assert json_response(conn, 400) == %{"error" => @invalid_limit_message}
    end

    test "returns error with non-integer limit", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:page",
          "limit" => "bad_limit"
        })

      assert json_response(conn, 400) == %{"error" => @invalid_limit_message}
    end

    test "returns error with negative integer limit", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "property" => "event:page",
          "limit" => -1
        })

      assert json_response(conn, 400) == %{"error" => @invalid_limit_message}
    end

    test "can paginate results", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/a", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/b", timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, pathname: "/c", timestamp: ~N[2021-01-01 00:00:00])
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
    test "returns time_on_page with imported data", %{conn: conn, site: site} do
      site =
        site
        |> Plausible.Site.start_import(~D[2005-01-01], Timex.today(), "Google Analytics", "ok")
        |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:imported_pages, page: "/A", time_on_page: 40, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/A", time_on_page: 110, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/B", time_on_page: 499, date: ~D[2021-01-01]),
        build(:pageview, pathname: "/A", user_id: 4, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 4, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "metrics" => "visitors,time_on_page",
          "with_imported" => "true"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/A",
                   "visitors" => 3,
                   "time_on_page" => 70.0
                 },
                 %{
                   "page" => "/B",
                   "visitors" => 2,
                   "time_on_page" => 499
                 }
               ]
             }
    end

    test "returns time_on_page in an event:page breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/A", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/A", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/A", user_id: 4, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 4, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, pathname: "/C", user_id: 4, timestamp: ~N[2021-01-01 00:02:30])
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "metrics" => "visitors,time_on_page"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/A",
                   "visitors" => 3,
                   "time_on_page" => 60.0
                 },
                 %{
                   "page" => "/B",
                   "visitors" => 2,
                   "time_on_page" => 90.0
                 },
                 %{
                   "page" => "/C",
                   "visitors" => 1,
                   "time_on_page" => nil
                 }
               ]
             }
    end

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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:goal",
          "metrics" => "visitors,events,conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "goal" => "Visit /blog**",
                   "visitors" => 2,
                   "events" => 2,
                   "conversion_rate" => 50
                 },
                 %{
                   "goal" => "Signup",
                   "visitors" => 1,
                   "events" => 2,
                   "conversion_rate" => 25
                 }
               ]
             }
    end

    test "returns conversion_rate alone in an event:goal breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", user_id: 1),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:goal",
          "metrics" => "conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "goal" => "Signup",
                   "conversion_rate" => 50
                 }
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:props:author",
          "filters" => "event:goal==Visit /blog**",
          "metrics" => "visitors,events,conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "author" => "Uku",
                   "visitors" => 3,
                   "events" => 3,
                   "conversion_rate" => 37.5
                 },
                 %{
                   "author" => "Marko",
                   "visitors" => 2,
                   "events" => 3,
                   "conversion_rate" => 25
                 },
                 %{
                   "author" => "(none)",
                   "visitors" => 1,
                   "events" => 1,
                   "conversion_rate" => 12.5
                 }
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:props:author",
          "filters" => "event:goal==Visit /blog**",
          "metrics" => "conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "author" => "Uku",
                   "conversion_rate" => 50
                 }
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:page",
          "filters" => "event:goal==Signup",
          "metrics" => "visitors,events,conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/en/register",
                   "visitors" => 2,
                   "events" => 2,
                   "conversion_rate" => 66.7
                 },
                 %{
                   "page" => "/it/register",
                   "visitors" => 1,
                   "events" => 2,
                   "conversion_rate" => 50
                 }
               ]
             }
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "event:page",
          "filters" => "event:goal==Signup",
          "metrics" => "conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/en/register",
                   "conversion_rate" => 50
                 }
               ]
             }
    end

    test "returns conversion_rate in a multi-goal filtered visit:screen_size breakdown", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, session_screen_size: "Mobile", name: "pageview"),
        build(:event, session_screen_size: "Mobile", name: "AddToCart"),
        build(:event, session_screen_size: "Mobile", name: "AddToCart"),
        build(:event, session_screen_size: "Desktop", name: "AddToCart", user_id: 1),
        build(:event, session_screen_size: "Desktop", name: "Purchase", user_id: 1),
        build(:event, session_screen_size: "Desktop", name: "pageview")
      ])

      # Make sure that revenue goals are treated the same
      # way as regular custom event goals
      insert(:goal, %{site: site, event_name: "Purchase", currency: :EUR})
      insert(:goal, %{site: site, event_name: "AddToCart"})

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "visit:device",
          "filters" => "event:goal==AddToCart|Purchase",
          "metrics" => "visitors,events,conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "device" => "Mobile",
                   "visitors" => 2,
                   "events" => 2,
                   "conversion_rate" => 66.7
                 },
                 %{
                   "device" => "Desktop",
                   "visitors" => 1,
                   "events" => 2,
                   "conversion_rate" => 50
                 }
               ]
             }
    end

    test "returns conversion_rate alone in a goal filtered visit:screen_size breakdown", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, session_screen_size: "Mobile", name: "pageview"),
        build(:event, session_screen_size: "Mobile", name: "AddToCart")
      ])

      insert(:goal, %{site: site, event_name: "AddToCart"})

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "visit:device",
          "filters" => "event:goal==AddToCart",
          "metrics" => "conversion_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "device" => "Mobile",
                   "conversion_rate" => 50
                 }
               ]
             }
    end

    test "returns conversion_rate for a browser_version breakdown with pagination limit", %{
      site: site,
      conn: conn
    } do
      populate_stats(site, [
        build(:pageview, session_browser: "Firefox", session_browser_version: "110"),
        build(:pageview, session_browser: "Firefox", session_browser_version: "110"),
        build(:pageview, session_browser: "Chrome", session_browser_version: "110"),
        build(:pageview, session_browser: "Chrome", session_browser_version: "110"),
        build(:pageview, session_browser: "Avast Secure Browser", session_browser_version: "110"),
        build(:pageview, session_browser: "Avast Secure Browser", session_browser_version: "110"),
        build(:event, name: "Signup", session_browser: "Edge", session_browser_version: "110")
      ])

      insert(:goal, site: site, event_name: "Signup")

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "property" => "visit:browser_version",
          "filters" => "event:goal==Signup",
          "metrics" => "visitors,conversion_rate",
          "page" => 1,
          "limit" => 1
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "browser" => "Edge",
                   "browser_version" => "110",
                   "visitors" => 1,
                   "conversion_rate" => 100.0
                 }
               ]
             }
    end

    test "all metrics for breakdown by visit prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          session_referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "signup",
          user_id: 1,
          session_referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          user_id: 1,
          session_referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          session_referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:pageview,
          session_referrer_source: "Twitter",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:source",
          "metrics" => "visitors,visits,pageviews,events,bounce_rate,visit_duration"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "source" => "Google",
                   "visitors" => 2,
                   "visits" => 2,
                   "bounce_rate" => 50,
                   "visit_duration" => 300,
                   "pageviews" => 3,
                   "events" => 4
                 },
                 %{
                   "source" => "Twitter",
                   "visitors" => 1,
                   "visits" => 1,
                   "bounce_rate" => 100,
                   "visit_duration" => 0,
                   "pageviews" => 1,
                   "events" => 1
                 }
               ]
             }
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
          session_referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        )
      ])

      conn =
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "visit:entry_page",
          "metrics" => "bounce_rate"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "entry_page" => "/entry-page-1",
                   "bounce_rate" => 0
                 },
                 %{
                   "entry_page" => "/entry-page-2",
                   "bounce_rate" => 100
                 }
               ]
             }
    end

    test "filter by custom event property", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          session_browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["business"],
          session_browser: "Safari",
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["package"],
          "meta.value": ["personal"],
          session_browser: "IE",
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
        get(conn, "/api/v1/stats/breakdown", %{
          "site_id" => site.domain,
          "period" => "day",
          "date" => "2021-01-01",
          "property" => "event:page",
          "metrics" => "visitors,pageviews,events,bounce_rate,visit_duration"
        })

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "page" => "/",
                   "visitors" => 2,
                   "bounce_rate" => 50,
                   "visit_duration" => 300,
                   "pageviews" => 2,
                   "events" => 2
                 },
                 %{
                   "page" => "/plausible.io",
                   "visitors" => 2,
                   "bounce_rate" => 100,
                   "visit_duration" => 0,
                   "pageviews" => 2,
                   "events" => 2
                 }
               ]
             }
    end
  end
end
