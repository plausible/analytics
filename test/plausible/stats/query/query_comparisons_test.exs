defmodule Plausible.Stats.QueryComparisonsTest do
  use Plausible.DataCase
  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryInclude}

  setup [:create_user, :create_site, :create_site_import]

  test "aggregates a single metric", %{site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 00:00:00])
    ])

    assert {:ok, query} =
             QueryBuilder.build(site, %ParsedQueryParams{
               metrics: [:pageviews],
               input_date_range: {:date_range, ~D[2021-01-07], ~D[2021-01-13]},
               include: %QueryInclude{compare: :previous_period}
             })

    assert %Stats.QueryResult{results: results} = Stats.query(site, query)

    assert results == [
             %{
               dimensions: [],
               metrics: [1],
               comparison: %{change: [-67], dimensions: [], metrics: [3]}
             }
           ]
  end

  test "timeseries comparison", %{site: site} do
    populate_stats(site, [
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-06 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-07 00:00:00]),
      build(:pageview, timestamp: ~N[2021-01-08 00:00:00])
    ])

    assert {:ok, query} =
             QueryBuilder.build(site, %ParsedQueryParams{
               metrics: [:pageviews],
               dimensions: ["time:day"],
               input_date_range: {:date_range, ~D[2021-01-07], ~D[2021-01-13]},
               include: %QueryInclude{compare: :previous_period}
             })

    assert %Stats.QueryResult{results: results} = Stats.query(site, query)

    assert results == [
             %{
               dimensions: ["2021-01-07"],
               metrics: [1],
               comparison: %{
                 dimensions: ["2020-12-31"],
                 metrics: [0],
                 change: [100]
               }
             },
             %{
               dimensions: ["2021-01-08"],
               metrics: [1],
               comparison: %{
                 dimensions: ["2021-01-01"],
                 metrics: [2],
                 change: [-50]
               }
             },
             %{
               dimensions: ["2021-01-09"],
               metrics: [0],
               comparison: %{
                 dimensions: ["2021-01-02"],
                 metrics: [0],
                 change: [0]
               }
             },
             %{
               dimensions: ["2021-01-10"],
               metrics: [0],
               comparison: %{
                 dimensions: ["2021-01-03"],
                 metrics: [0],
                 change: [0]
               }
             },
             %{
               dimensions: ["2021-01-11"],
               metrics: [0],
               comparison: %{
                 dimensions: ["2021-01-04"],
                 metrics: [0],
                 change: [0]
               }
             },
             %{
               dimensions: ["2021-01-12"],
               metrics: [0],
               comparison: %{
                 dimensions: ["2021-01-05"],
                 metrics: [0],
                 change: [0]
               }
             },
             %{
               dimensions: ["2021-01-13"],
               metrics: [0],
               comparison: %{
                 dimensions: ["2021-01-06"],
                 metrics: [1],
                 change: [-100]
               }
             }
           ]
  end

  test "timeseries last 28d period compares the same period with and without match_day_of_week=true",
       %{
         site: site
       } do
    now = ~U[2021-06-10 12:00:00Z]
    today = DateTime.to_date(now)

    {:ok, query1} =
      QueryBuilder.build(site, %ParsedQueryParams{
        metrics: [:visitors],
        dimensions: ["time"],
        input_date_range: {:last_n_days, 28},
        include: %QueryInclude{time_labels: true, compare: :previous_period},
        now: now
      })

    query2 = Stats.Query.set_include(query1, :compare_match_day_of_week, true)

    assert %Stats.QueryResult{results: results1} = Stats.query(site, query1)
    assert %Stats.QueryResult{results: results2} = Stats.query(site, query2)

    assert results1 == results2

    expected_first_date = today |> Date.shift(day: -28) |> Date.to_iso8601()
    expected_last_date = today |> Date.shift(day: -1) |> Date.to_iso8601()
    expected_comparison_first_date = today |> Date.shift(day: -56) |> Date.to_iso8601()
    expected_comparison_last_date = today |> Date.shift(day: -29) |> Date.to_iso8601()

    assert %{
             dimensions: [actual_first_date],
             comparison: %{
               dimensions: [actual_comparison_first_date]
             }
           } = List.first(results1)

    assert %{
             dimensions: [actual_last_date],
             comparison: %{
               dimensions: [actual_comparison_last_date]
             }
           } = List.last(results1)

    assert actual_first_date == expected_first_date
    assert actual_last_date == expected_last_date
    assert actual_comparison_first_date == expected_comparison_first_date
    assert actual_comparison_last_date == expected_comparison_last_date
  end

  test "timeseries last 91d period in year_over_year comparison", %{
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

    assert {:ok, query} =
             QueryBuilder.build(site, %ParsedQueryParams{
               metrics: [:visitors],
               dimensions: ["time:day"],
               input_date_range: {:last_n_days, 91},
               include: %QueryInclude{time_labels: true, compare: :year_over_year},
               now: ~U[2022-07-01 14:00:00Z]
             })

    assert %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

    time_labels = meta[:time_labels]

    assert "2022-04-01" = List.first(time_labels)
    assert "2022-04-05" = Enum.at(time_labels, 4)
    assert "2022-06-30" = List.last(time_labels)

    assert %{
             dimensions: ["2022-04-01"],
             metrics: [1],
             comparison: %{
               dimensions: ["2021-04-01"],
               metrics: [2]
             }
           } = Enum.find(results, &(&1[:dimensions] == ["2022-04-01"]))

    assert %{
             dimensions: ["2022-04-05"],
             metrics: [1],
             comparison: %{
               dimensions: ["2021-04-05"],
               metrics: [2]
             }
           } = Enum.find(results, &(&1[:dimensions] == ["2022-04-05"]))

    assert %{
             dimensions: ["2022-06-30"],
             metrics: [1],
             comparison: %{
               dimensions: ["2021-06-30"],
               metrics: [1]
             }
           } = Enum.find(results, &(&1[:dimensions] == ["2022-06-30"]))
  end

  test "dimensional comparison with low limit", %{site: site} do
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

    {:ok, page_one_query} =
      QueryBuilder.build(site, %ParsedQueryParams{
        metrics: [:visitors, :percentage],
        input_date_range: {:date_range, ~D[2021-01-07], ~D[2021-01-13]},
        dimensions: ["visit:browser"],
        include: %QueryInclude{
          compare: :previous_period
        },
        pagination: %{limit: 2, offset: 0}
      })

    assert %Stats.QueryResult{results: page_one_results} = Stats.query(site, page_one_query)

    assert page_one_results == [
             %{
               dimensions: ["Chrome"],
               metrics: [3, 50.0],
               comparison: %{
                 dimensions: ["Chrome"],
                 metrics: [1, 12.5],
                 change: [200, 300]
               }
             },
             %{
               dimensions: ["Firefox"],
               metrics: [2, 33.33],
               comparison: %{
                 dimensions: ["Firefox"],
                 metrics: [4, 50.0],
                 change: [-50, -33]
               }
             }
           ]

    page_two_query = Stats.Query.set(page_one_query, pagination: %{limit: 2, offset: 2})

    assert %Stats.QueryResult{results: page_two_results} = Stats.query(site, page_two_query)

    assert page_two_results == [
             %{
               dimensions: ["Safari"],
               metrics: [1, 16.67],
               comparison: %{
                 dimensions: ["Safari"],
                 metrics: [3, 37.5],
                 change: [-67, -56]
               }
             }
           ]
  end

  test "dimensional comparison with imported data", %{
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

    assert {:ok, query} =
             QueryBuilder.build(site, %ParsedQueryParams{
               metrics: [:visitors, :percentage],
               input_date_range: {:date_range, ~D[2021-01-07], ~D[2021-01-13]},
               dimensions: ["visit:browser"],
               include: %QueryInclude{
                 imports: true,
                 compare: :previous_period
               },
               pagination: %{limit: 2, offset: 0}
             })

    assert %Stats.QueryResult{results: results} = Stats.query(site, query)

    assert results == [
             %{
               dimensions: ["Chrome"],
               metrics: [2, 66.67],
               comparison: %{
                 dimensions: ["Chrome"],
                 metrics: [40, 40.0],
                 change: [-95, 67]
               }
             },
             %{
               dimensions: ["Firefox"],
               metrics: [1, 33.33],
               comparison: %{
                 dimensions: ["Firefox"],
                 metrics: [50, 50.0],
                 change: [-98, -33]
               }
             }
           ]
  end

  describe "custom comparison range" do
    test "can use date range for custom comparison", %{site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:pageviews],
                 input_date_range: {:date_range, ~D[2021-01-07], ~D[2021-01-13]},
                 include: %QueryInclude{compare: {:date_range, ~D[2021-01-01], ~D[2021-01-06]}}
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{
                 dimensions: [],
                 metrics: [1],
                 comparison: %{change: [-50], dimensions: [], metrics: [2]}
               }
             ]
    end

    test "can use datetime range for custom comparison", %{site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 01:00:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 05:25:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 05:26:00]),
        build(:pageview, timestamp: ~N[2021-01-02 04:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 02:00:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:visitors, :pageviews],
                 input_date_range:
                   {:datetime_range, ~U[2021-01-02 03:00:00Z], ~U[2021-01-03 02:59:59Z]},
                 include: %QueryInclude{
                   compare: {:datetime_range, ~U[2021-01-01 03:00:00Z], ~U[2021-01-02 02:59:59Z]}
                 }
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{
                 dimensions: [],
                 metrics: [2, 2],
                 comparison: %{change: [100, 0], dimensions: [], metrics: [1, 2]}
               }
             ]
    end

    test "custom datetime range comparison handles timezones correctly", %{user: user} do
      weird_tz_site = new_site(owner: user, timezone: "America/Havana")

      populate_stats(weird_tz_site, [
        # 03:00 America/Havana
        build(:pageview, timestamp: ~N[2021-01-01 08:00:00]),
        # 05:25 America/Havana
        build(:pageview, timestamp: ~N[2021-01-01 10:25:00]),
        # 04:00 America/Havana
        build(:pageview, timestamp: ~N[2021-01-02 09:00:00]),
        # 02:00 America/Havana
        build(:pageview, timestamp: ~N[2021-01-03 08:00:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(weird_tz_site, %ParsedQueryParams{
                 metrics: [:pageviews],
                 input_date_range:
                   {:datetime_range, ~U[2021-01-02 03:00:00Z], ~U[2021-01-03 02:59:59Z]},
                 include: %QueryInclude{
                   compare: {:datetime_range, ~U[2021-01-01 03:00:00Z], ~U[2021-01-02 02:59:59Z]}
                 }
               })

      assert %Stats.QueryResult{results: results} = Stats.query(weird_tz_site, query)

      assert results == [
               %{
                 dimensions: [],
                 metrics: [1],
                 comparison: %{change: [-50], dimensions: [], metrics: [2]}
               }
             ]
    end
  end
end
