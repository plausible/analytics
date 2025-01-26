defmodule PlausibleWeb.Api.ExternalStatsController.QueryComparisonsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key, :create_site_import]

  test "aggregates a single metric", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-01-07", "2021-01-13"],
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      })

    assert_matches json_response(conn, 200), %{
      "results" => [
        %{
          "dimensions" => [],
          "metrics" => [1],
          "comparison" => %{"change" => [-67], "dimensions" => [], "metrics" => [3]}
        }
      ],
      "meta" => %{},
      "query" =>
        response_query(site, %{
          "metrics" => ["pageviews"],
          "date_range" => ["2021-01-07T00:00:00+00:00", "2021-01-13T23:59:59+00:00"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })
    }
  end

  test "timeseries comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-06 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-08 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-01-07", "2021-01-13"],
        "dimensions" => ["time:day"],
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      })

    assert_matches json_response(conn, 200), %{
      "results" => [
        %{
          "dimensions" => ["2021-01-07"],
          "metrics" => [1],
          "comparison" => %{
            "dimensions" => ["2020-12-31"],
            "metrics" => [0],
            "change" => [100]
          }
        },
        %{
          "dimensions" => ["2021-01-08"],
          "metrics" => [1],
          "comparison" => %{
            "dimensions" => ["2021-01-01"],
            "metrics" => [2],
            "change" => [-50]
          }
        },
        %{
          "dimensions" => ["2021-01-09"],
          "metrics" => [0],
          "comparison" => %{
            "dimensions" => ["2021-01-02"],
            "metrics" => [0],
            "change" => [0]
          }
        },
        %{
          "dimensions" => ["2021-01-10"],
          "metrics" => [0],
          "comparison" => %{
            "dimensions" => ["2021-01-03"],
            "metrics" => [0],
            "change" => [0]
          }
        },
        %{
          "dimensions" => ["2021-01-11"],
          "metrics" => [0],
          "comparison" => %{
            "dimensions" => ["2021-01-04"],
            "metrics" => [0],
            "change" => [0]
          }
        },
        %{
          "dimensions" => ["2021-01-12"],
          "metrics" => [0],
          "comparison" => %{
            "dimensions" => ["2021-01-05"],
            "metrics" => [0],
            "change" => [0]
          }
        },
        %{
          "dimensions" => ["2021-01-13"],
          "metrics" => [0],
          "comparison" => %{
            "dimensions" => ["2021-01-06"],
            "metrics" => [1],
            "change" => [-100]
          }
        }
      ],
      "meta" => %{},
      "query" =>
        response_query(site, %{
          "date_range" => ["2021-01-07T00:00:00+00:00", "2021-01-13T23:59:59+00:00"],
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })
    }
  end

  test "dimensional comparison with low limit", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Safari", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Safari", timestamp: ~N[2021-01-08 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "percentage"],
        "date_range" => ["2021-01-07", "2021-01-13"],
        "dimensions" => ["visit:browser"],
        "include" => %{
          "comparisons" => %{"mode" => "previous_period"}
        },
        "pagination" => %{"limit" => 2}
      })

    assert_matches json_response(conn, 200), %{
      "results" => [
        %{
          "dimensions" => ["Chrome"],
          "metrics" => [3, 50.0],
          "comparison" => %{
            "dimensions" => ["Chrome"],
            "metrics" => [1, 12.5],
            "change" => [200, 300]
          }
        },
        %{
          "dimensions" => ["Firefox"],
          "metrics" => [2, 33.3],
          "comparison" => %{
            "dimensions" => ["Firefox"],
            "metrics" => [4, 50.0],
            "change" => [-50, -33]
          }
        }
      ],
      "meta" => %{},
      "query" =>
        response_query(site, %{
          "date_range" => ["2021-01-07T00:00:00+00:00", "2021-01-13T23:59:59+00:00"],
          "metrics" => ["visitors", "percentage"],
          "dimensions" => ["visit:browser"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })
    }

    conn2 =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "percentage"],
        "date_range" => ["2021-01-07", "2021-01-13"],
        "dimensions" => ["visit:browser"],
        "include" => %{
          "comparisons" => %{"mode" => "previous_period"}
        },
        "pagination" => %{"limit" => 2, "offset" => 2}
      })

    assert_matches json_response(conn2, 200), %{
      "results" => [
        %{
          "dimensions" => ["Safari"],
          "metrics" => [1, 16.7],
          "comparison" => %{
            "dimensions" => ["Safari"],
            "metrics" => [3, 37.5],
            "change" => [-67, -55]
          }
        }
      ],
      "meta" => %{},
      "query" =>
        response_query(site, %{
          "date_range" => ["2021-01-07T00:00:00+00:00", "2021-01-13T23:59:59+00:00"],
          "metrics" => ["visitors", "percentage"],
          "dimensions" => ["visit:browser"],
          "include" => %{"comparisons" => %{"mode" => "previous_period"}}
        })
    }
  end

  test "dimensional comparison with imported data", %{
    conn: conn,
    site: site,
    site_import: site_import
  } do
    populate_stats(site, site_import.id, [
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-07 00:00:00]),
      build(:imported_browsers,
        date: ~D[2021-01-01],
        browser: "Firefox",
        browser_version: "121",
        visitors: 50
      ),
      build(:imported_browsers,
        date: ~D[2021-01-01],
        browser: "Chrome",
        browser_version: "99",
        visitors: 39
      ),
      build(:imported_browsers,
        date: ~D[2021-01-01],
        browser: "Safari",
        browser_version: "99",
        visitors: 10
      ),
      build(:imported_visitors, date: ~D[2021-01-01], visitors: 99)
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "percentage"],
        "date_range" => ["2021-01-07", "2021-01-13"],
        "dimensions" => ["visit:browser"],
        "include" => %{
          "imports" => true,
          "comparisons" => %{"mode" => "previous_period"}
        },
        "pagination" => %{"limit" => 2}
      })

    assert_matches json_response(conn, 200), %{
      "results" => [
        %{
          "dimensions" => ["Chrome"],
          "metrics" => [2, 66.7],
          "comparison" => %{
            "dimensions" => ["Chrome"],
            "metrics" => [40, 40.0],
            "change" => [-95, 67]
          }
        },
        %{
          "dimensions" => ["Firefox"],
          "metrics" => [1, 33.3],
          "comparison" => %{
            "dimensions" => ["Firefox"],
            "metrics" => [50, 50.0],
            "change" => [-98, -33]
          }
        }
      ],
      "meta" => %{
        "imports_included" => true
      },
      "query" =>
        response_query(site, %{
          "date_range" => ["2021-01-07T00:00:00+00:00", "2021-01-13T23:59:59+00:00"],
          "metrics" => ["visitors", "percentage"],
          "dimensions" => ["visit:browser"],
          "include" => %{"imports" => true, "comparisons" => %{"mode" => "previous_period"}}
        })
    }
  end
end
