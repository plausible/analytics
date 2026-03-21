defmodule Plausible.Stats.QueryTest do
  use Plausible.DataCase
  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryInclude}

  @user_id 123

  setup [:create_user, :create_site]

  describe "timeseries" do
    test "breakdown by time:minute (internal API), counts visitors and visits in all buckets their session was active in",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :pageviews],
          input_date_range: {:datetime_range, ~U[2021-01-01 00:00:00Z], ~U[2021-01-01 00:10:00Z]},
          dimensions: ["time:minute"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 1]},
               %{dimensions: ["2021-01-01 00:01:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:02:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:03:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:04:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:05:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:06:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:07:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:08:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:09:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:10:00"], metrics: [1, 1, 1]}
             ]
    end

    test "breakdown by time:hour (internal API), counts visitors and visits in all buckets their session was active in",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:20:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:40:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 01:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 01:20:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :visit_duration],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-01-02]},
          dimensions: ["time:hour"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 01:00:00"], metrics: [1, 1, 3600]}
             ]
    end

    test "shows month to date with time labels trimmed", %{site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: :month,
          dimensions: ["time:day"],
          include: %QueryInclude{trim_relative_date_range: true},
          now: ~U[2021-01-15 12:00:00Z]
        })

      %Stats.QueryResult{results: results, query: query} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01"], metrics: [1]},
               %{dimensions: ["2021-01-15"], metrics: [1]}
             ]

      assert query[:date_range] == [
               "2021-01-01T00:00:00Z",
               "2021-01-15T23:59:59Z"
             ]
    end

    test "visitors and visits are smeared across time:minute buckets but visit_duration is not",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:05:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:08:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :visit_duration, :pageviews],
          input_date_range: {:datetime_range, ~U[2021-01-01 00:00:00Z], ~U[2021-01-01 00:30:00Z]},
          dimensions: ["time:minute"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 0, 1]},
               %{dimensions: ["2021-01-01 00:01:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:02:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:03:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:04:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:05:00"], metrics: [2, 2, 0, 1]},
               %{dimensions: ["2021-01-01 00:06:00"], metrics: [2, 2, 0, 0]},
               %{dimensions: ["2021-01-01 00:07:00"], metrics: [2, 2, 0, 0]},
               %{dimensions: ["2021-01-01 00:08:00"], metrics: [2, 2, 180, 1]},
               %{dimensions: ["2021-01-01 00:09:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:10:00"], metrics: [1, 1, 600, 1]}
             ]
    end
  end

  describe "timeseries with comparisons" do
    test "returns more original time range buckets than comparison buckets",
         %{site: site} do
      populate_stats(site, [
        # original time range
        build(:pageview, user_id: 123, timestamp: ~N[2026-01-03 00:00:00]),
        build(:pageview, user_id: 123, timestamp: ~N[2026-01-03 00:10:00]),
        build(:pageview, timestamp: ~N[2026-01-05 00:00:00]),
        # comparison time range
        build(:pageview, timestamp: ~N[2025-12-16 00:00:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :pageviews],
          input_date_range: {:date_range, ~D[2025-12-25], ~D[2026-01-06]},
          dimensions: ["time:week"],
          include: %QueryInclude{
            compare: {:date_range, ~D[2025-12-12], ~D[2025-12-21]},
            time_labels: true,
            time_label_result_indices: true
          }
        })

      %Stats.QueryResult{results: results, comparison_results: comparison_results, meta: meta} =
        Stats.query(site, query)

      assert results == [
               %{dimensions: ["2025-12-29"], metrics: [1, 2]},
               %{dimensions: ["2026-01-05"], metrics: [1, 1]}
             ]

      assert comparison_results == [
               %{dimensions: ["2025-12-15"], metrics: [1, 1], change: [0, 100]}
             ]

      assert meta[:time_labels] == ["2025-12-25", "2025-12-29", "2026-01-05"]
      assert meta[:time_label_result_indices] == [nil, 0, 1]
      assert meta[:comparison_time_labels] == ["2025-12-12", "2025-12-15"]
      assert meta[:comparison_time_label_result_indices] == [nil, 0]
    end

    test "can return more comparison time buckets than original time range buckets",
         %{site: site} do
      populate_stats(site, [
        # original time range
        build(:pageview, user_id: 123, timestamp: ~N[2021-02-01 00:00:00]),
        build(:pageview, user_id: 123, timestamp: ~N[2021-02-01 00:10:00]),
        build(:pageview, timestamp: ~N[2021-02-01 00:00:00]),
        # comparison time range
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-04 00:00:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :pageviews],
          input_date_range: {:date_range, ~D[2021-02-01], ~D[2021-02-01]},
          dimensions: ["time:day"],
          include: %QueryInclude{
            compare: {:date_range, ~D[2021-01-01], ~D[2021-01-05]},
            time_labels: true,
            time_label_result_indices: true
          }
        })

      %Stats.QueryResult{results: results, comparison_results: comparison_results, meta: meta} =
        Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-02-01"], metrics: [2, 3]}
             ]

      assert comparison_results == [
               %{dimensions: ["2021-01-01"], metrics: [2, 2], change: [0, 50]},
               %{dimensions: ["2021-01-02"], metrics: [1, 1], change: nil},
               %{dimensions: ["2021-01-04"], metrics: [1, 1], change: nil}
             ]

      assert meta[:time_labels] == ["2021-02-01"]

      assert meta[:comparison_time_labels] == [
               "2021-01-01",
               "2021-01-02",
               "2021-01-03",
               "2021-01-04",
               "2021-01-05"
             ]

      assert meta[:time_label_result_indices] == [0]
      assert meta[:comparison_time_label_result_indices] == [0, 1, nil, 2, nil]
    end
  end

  describe "session smearing respects query date range boundaries" do
    test "time:hour does not include buckets from outside the query range",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 23:55:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-02 00:10:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-02 23:55:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-03 00:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:date_range, ~D[2021-01-02], ~D[2021-01-02]},
          dimensions: ["time:hour"],
          include: %QueryInclude{total_rows: true}
        })

      %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-02 00:00:00"], metrics: [1]},
               %{dimensions: ["2021-01-02 23:00:00"], metrics: [1]}
             ]

      assert meta[:total_rows] == 2
    end

    test "time:hour does not include buckets from outside the query range (non-UTC timezone)",
         %{site: site} do
      # America/New_York is UTC-5 in January
      site = %{site | timezone: "America/New_York"}

      populate_stats(site, [
        # 2020-12-31 23:55 in NYC (outside of query range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 04:55:00]),
        # 2021-01-01 00:10 in NYC (in query range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 05:10:00]),
        # 2021-01-01 23:55 in NYC (in query range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-02 04:55:00]),
        # 2021-01-02 00:10 in NYC (outside of query range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-02 05:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-01-01]},
          dimensions: ["time:hour"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1]},
               %{dimensions: ["2021-01-01 23:00:00"], metrics: [1]}
             ]
    end

    test "time:minute does not include buckets from outside the query range",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:05:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:20:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:08:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:datetime_range, ~U[2021-01-01 00:08:00Z], ~U[2021-01-01 00:12:00Z]},
          dimensions: ["time:minute"],
          include: %QueryInclude{total_rows: true}
        })

      %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:08:00"], metrics: [2]},
               %{dimensions: ["2021-01-01 00:09:00"], metrics: [2]},
               %{dimensions: ["2021-01-01 00:10:00"], metrics: [2]},
               %{dimensions: ["2021-01-01 00:11:00"], metrics: [1]},
               %{dimensions: ["2021-01-01 00:12:00"], metrics: [1]}
             ]

      assert meta[:total_rows] == 5
    end

    test "time:minute does not include buckets from outside the query range (non-UTC timezone)",
         %{site: site} do
      # America/New_York is UTC-5 in January
      site = %{site | timezone: "America/New_York"}

      populate_stats(site, [
        # 2020-12-31 23:59:00 in NYC (outside of queried range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 04:59:00]),
        # 2021-01-01 00:02:00 in NYC (in queried range)
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 05:02:00]),
        # 2021-01-01 23:59:00 in NYC (in queried range)
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-02 04:59:00]),
        # 2021-01-02 00:01:00 in NYC (outside of queried range)
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-02 05:01:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: :day,
          relative_date: ~D[2021-01-01],
          dimensions: ["time:minute"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1]},
               %{dimensions: ["2021-01-01 00:01:00"], metrics: [1]},
               %{dimensions: ["2021-01-01 00:02:00"], metrics: [1]},
               %{dimensions: ["2021-01-01 23:59:00"], metrics: [1]}
             ]
    end

    test "time:day clamps sessions extending past the query range end into the last bucket",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-31 23:55:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-02-01 00:05:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-01-31]},
          dimensions: ["time:day"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      # Without clamping the session would bucket to "2021-02-01" (outside range)
      assert results == [
               %{dimensions: ["2021-01-31"], metrics: [1]}
             ]
    end

    test "time:week clamps sessions extending past the query range end into the last bucket",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-31 23:55:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-02-01 00:05:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-01-31]},
          dimensions: ["time:week"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      # Without clamping the session would bucket to "2021-02-01" (outside range).
      # Clamped to Jan 31 23:59:59 -> toMonday(Jan 31) = Jan 25.
      assert results == [
               %{dimensions: ["2021-01-25"], metrics: [1]}
             ]
    end

    test "time:month clamps sessions extending past the query range end into the last bucket",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-02-28 23:55:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-03-01 00:05:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-02-28]},
          dimensions: ["time:month"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      # Without clamping the session would bucket to "2021-03-01" (outside range).
      # Clamped to Feb 28 23:59:59 -> toStartOfMonth -> Feb 1.
      assert results == [
               %{dimensions: ["2021-02-01"], metrics: [1]}
             ]
    end
  end
end
