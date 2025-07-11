defmodule PlausibleWeb.Api.ExternalStatsController.QueryComparisonsTest do
  use PlausibleWeb.ConnCase, async: true

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

    assert json_response(conn, 200)["results"] == [
             %{
               "dimensions" => [],
               "metrics" => [1],
               "comparison" => %{"change" => [-67], "dimensions" => [], "metrics" => [3]}
             }
           ]
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

    assert json_response(conn, 200)["results"] == [
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
           ]
  end

  test "timeseries last 28d period compares the same period with and without match_day_of_week=true",
       %{
         conn: conn,
         site: site
       } do
    today = ~D[2021-06-10]

    make_request = fn match_day_of_week ->
      conn
      |> post("/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "28d",
        "date" => Date.to_iso8601(today),
        "dimensions" => ["time"],
        "include" => %{
          "time_labels" => true,
          "comparisons" => %{
            "mode" => "previous_period",
            "match_day_of_week" => match_day_of_week
          }
        }
      })
      |> json_response(200)
    end

    assert %{"results" => results1} = make_request.(false)
    assert %{"results" => results2} = make_request.(true)

    assert results1 == results2

    expected_first_date = today |> Date.shift(day: -28) |> Date.to_iso8601()
    expected_last_date = today |> Date.shift(day: -1) |> Date.to_iso8601()
    expected_comparison_first_date = today |> Date.shift(day: -56) |> Date.to_iso8601()
    expected_comparison_last_date = today |> Date.shift(day: -29) |> Date.to_iso8601()

    assert %{
             "dimensions" => [actual_first_date],
             "comparison" => %{
               "dimensions" => [actual_comparison_first_date]
             }
           } = List.first(results1)

    assert %{
             "dimensions" => [actual_last_date],
             "comparison" => %{
               "dimensions" => [actual_comparison_last_date]
             }
           } = List.last(results1)

    assert actual_first_date == expected_first_date
    assert actual_last_date == expected_last_date
    assert actual_comparison_first_date == expected_comparison_first_date
    assert actual_comparison_last_date == expected_comparison_last_date
  end

  test "timeseries last 91d period in year_over_year comparison", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-04-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-04-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-04-05 00:00:00]),
      build(:pageview, timestamp: ~N[2021-04-05 00:00:00]),
      build(:pageview, timestamp: ~N[2021-06-30 00:00:00]),
      build(:pageview, timestamp: ~N[2022-04-01 00:00:00]),
      build(:pageview, timestamp: ~N[2022-04-05 00:00:00]),
      build(:pageview, timestamp: ~N[2022-06-30 00:00:00]),
      build(:pageview, timestamp: ~N[2022-07-01 00:00:00])
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "91d",
        "date" => "2022-07-01",
        "dimensions" => ["time:day"],
        "include" => %{
          "time_labels" => true,
          "comparisons" => %{"mode" => "year_over_year"}
        }
      })

    assert %{
             "results" => results,
             "meta" => %{"time_labels" => time_labels}
           } = json_response(conn, 200)

    assert "2022-04-01" = List.first(time_labels)
    assert "2022-04-05" = Enum.at(time_labels, 4)
    assert "2022-06-30" = List.last(time_labels)

    assert %{
             "dimensions" => ["2022-04-01"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2021-04-01"],
               "metrics" => [2]
             }
           } = Enum.find(results, &(&1["dimensions"] == ["2022-04-01"]))

    assert %{
             "dimensions" => ["2022-04-05"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2021-04-05"],
               "metrics" => [2]
             }
           } = Enum.find(results, &(&1["dimensions"] == ["2022-04-05"]))

    assert %{
             "dimensions" => ["2022-06-30"],
             "metrics" => [1],
             "comparison" => %{
               "dimensions" => ["2021-06-30"],
               "metrics" => [1]
             }
           } = Enum.find(results, &(&1["dimensions"] == ["2022-06-30"]))
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

    assert json_response(conn, 200)["results"] == [
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
           ]

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

    assert json_response(conn2, 200)["results"] == [
             %{
               "dimensions" => ["Safari"],
               "metrics" => [1, 16.7],
               "comparison" => %{
                 "dimensions" => ["Safari"],
                 "metrics" => [3, 37.5],
                 "change" => [-67, -55]
               }
             }
           ]
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

    assert json_response(conn, 200)["results"] == [
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
           ]
  end
end
