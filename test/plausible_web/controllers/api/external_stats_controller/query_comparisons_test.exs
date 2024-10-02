defmodule PlausibleWeb.Api.ExternalStatsController.QueryComparisonsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_new_site, :create_api_key, :use_api_key]

  test "aggregate previous_period comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-04-20 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-03 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-05-01", "2021-05-31"],
        "include" => %{
          "comparisons" => %{
            "mode" => "previous_period"
          }
        }
      })

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => [],
               "metrics" => [3],
               "comparison" => %{"dimensions" => [], "metrics" => [1], "change" => [200]}
             }
           ]
  end

  test "utm_source previous_period comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-04-20 00:00:00], utm_source: "Google"),
      build(:pageview, timestamp: ~N[2021-04-21 00:00:00], utm_source: "Google"),
      build(:pageview, timestamp: ~N[2021-04-22 00:00:00], utm_source: "Google"),
      build(:pageview, timestamp: ~N[2021-04-23 00:00:00], utm_source: "Google"),
      build(:pageview, timestamp: ~N[2021-04-24 00:00:00], utm_source: "Bing"),
      build(:pageview, timestamp: ~N[2021-05-01 00:00:00], utm_source: "Google"),
      build(:pageview, timestamp: ~N[2021-05-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-03 00:00:00], utm_source: "Facebook"),
      build(:pageview, timestamp: ~N[2021-05-04 00:00:00], utm_source: "Google")
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-05-01", "2021-05-31"],
        "dimensions" => ["visit:utm_source"],
        "include" => %{
          "comparisons" => %{
            "mode" => "previous_period"
          }
        }
      })

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => ["Google"],
               "metrics" => [2],
               "comparison" => %{"dimensions" => ["Google"], "metrics" => [4], "change" => [-50]}
             },
             %{
               "dimensions" => ["Facebook"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["Facebook"],
                 "metrics" => [0],
                 "change" => [100]
               }
             },
             %{
               "dimensions" => ["(not set)"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["(not set)"],
                 "metrics" => [0],
                 "change" => [100]
               }
             }
           ]
  end

  test "time series previous_period comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-05-27 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-28 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-30 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-30 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-31 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-03 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-06-01", "2021-06-04"],
        "dimensions" => ["time:day"],
        "include" => %{
          "comparisons" => %{
            "mode" => "previous_period"
          }
        }
      })

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => ["2021-06-01"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-28"],
                 "metrics" => [1],
                 "change" => [0]
               }
             },
             %{
               "dimensions" => ["2021-06-02"],
               "metrics" => [2],
               "comparison" => %{
                 "dimensions" => ["2021-05-29"],
                 "metrics" => [0],
                 "change" => [100]
               }
             },
             %{
               "dimensions" => ["2021-06-03"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-30"],
                 "metrics" => [2],
                 "change" => [-50]
               }
             },
             %{
               "dimensions" => ["2021-06-04"],
               "metrics" => [0],
               "comparison" => %{
                 "dimensions" => ["2021-05-31"],
                 "metrics" => [1],
                 "change" => [-100]
               }
             }
           ]
  end

  test "time series previous_period comparison with match_day_of_week", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-05-27 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-28 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-30 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-30 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-31 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-03 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-06-01", "2021-06-04"],
        "dimensions" => ["time:day"],
        "include" => %{
          "comparisons" => %{
            "mode" => "previous_period",
            "match_day_of_week" => true
          }
        }
      })

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => ["2021-06-01"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-25"],
                 "metrics" => [0],
                 "change" => [100]
               }
             },
             %{
               "dimensions" => ["2021-06-02"],
               "metrics" => [2],
               "comparison" => %{
                 "dimensions" => ["2021-05-26"],
                 "metrics" => [0],
                 "change" => [100]
               }
             },
             %{
               "dimensions" => ["2021-06-03"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-27"],
                 "metrics" => [1],
                 "change" => [0]
               }
             },
             %{
               "dimensions" => ["2021-06-04"],
               "metrics" => [0],
               "comparison" => %{
                 "dimensions" => ["2021-05-28"],
                 "metrics" => [1],
                 "change" => [-100]
               }
             }
           ]
  end

  test "time series year_over_year comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
      build(:pageview, timestamp: ~N[2020-01-30 00:00:00]),
      build(:pageview, timestamp: ~N[2020-01-31 00:00:00]),
      build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
      build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
      build(:pageview, timestamp: ~N[2019-01-31 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2020-01-01", "2020-01-31"],
        "dimensions" => ["time:day"],
        "include" => %{
          "comparisons" => %{
            "mode" => "year_over_year"
          }
        }
      })

    results = json_response(conn, 200)["results"]
    find_result = fn date -> Enum.find(results, &(&1["dimensions"] == [date])) end

    assert find_result.("2020-01-01") == %{
             "dimensions" => ["2020-01-01"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2019-01-01"],
               "metrics" => [2],
               "change" => [-50]
             }
           }

    assert find_result.("2020-01-05") == %{
             "dimensions" => ["2020-01-05"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2019-01-05"],
               "metrics" => [2],
               "change" => [-50]
             }
           }

    assert find_result.("2020-01-31") == %{
             "dimensions" => ["2020-01-31"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2019-01-31"],
               "metrics" => [1],
               "change" => [0]
             }
           }
  end

  test "time series custom date range comparison", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-05-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-03 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-03 00:00:00]),
      build(:pageview, timestamp: ~N[2021-05-04 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-03 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["pageviews"],
        "date_range" => ["2021-06-01", "2021-06-04"],
        "dimensions" => ["time:day"],
        "include" => %{
          "comparisons" => %{
            "mode" => "custom",
            "date_range" => ["2021-05-01", "2021-05-04"]
          }
        }
      })

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => ["2021-06-01"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-01"],
                 "metrics" => [1],
                 "change" => [0]
               }
             },
             %{
               "dimensions" => ["2021-06-02"],
               "metrics" => [2],
               "comparison" => %{
                 "dimensions" => ["2021-05-02"],
                 "metrics" => [1],
                 "change" => [100]
               }
             },
             %{
               "dimensions" => ["2021-06-03"],
               "metrics" => [1],
               "comparison" => %{
                 "dimensions" => ["2021-05-03"],
                 "metrics" => [2],
                 "change" => [-50]
               }
             },
             %{
               "dimensions" => ["2021-06-04"],
               "metrics" => [0],
               "comparison" => %{
                 "dimensions" => ["2021-05-04"],
                 "metrics" => [1],
                 "change" => [-100]
               }
             }
           ]
  end
end
