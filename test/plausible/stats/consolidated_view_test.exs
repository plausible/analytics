defmodule Plausible.Stats.ConsolidatedViewTest do
  use Plausible.DataCase, async: true

  on_ee do
    import Plausible.Teams.Test

    test "returns stats for a consolidated view merged with placeholder" do
      fixed_now = ~N[2023-10-26 10:00:15]
      owner = new_user()
      site1 = new_site(owner: owner)
      site2 = new_site(owner: owner)

      user_id = 111

      populate_stats(site1, [
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:01:00]),
        # this one is at the end of the range
        build(:pageview, timestamp: ~N[2023-10-26 10:00:14])
      ])

      populate_stats(site2, [
        # this one is at the beginning of the range
        build(:pageview, timestamp: ~N[2023-10-25 11:01:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00])
      ])

      view = new_consolidated_view(team_of(owner))

      result = Plausible.Stats.ConsolidatedView.overview_24h(view, fixed_now)

      assert %{
               visitors_change: 100,
               pageviews_change: 100,
               visits_change: 100,
               visitors: 5,
               visits: 5,
               pageviews: 6,
               views_per_visit: 1.2,
               intervals: [
                 %{interval: ~N[2023-10-25 10:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 11:00:00], visitors: 1},
                 %{interval: ~N[2023-10-25 12:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 13:00:00], visitors: 2},
                 %{interval: ~N[2023-10-25 14:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 15:00:00], visitors: 1},
                 %{interval: ~N[2023-10-25 16:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 17:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 18:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 19:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 20:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 21:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 22:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 23:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 00:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 01:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 02:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 03:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 04:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 05:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 06:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 07:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 08:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 09:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 10:00:00], visitors: 1}
               ]
             } = result
    end

    test "compatibility with individual site stats" do
      fixed_now = ~N[2025-10-20 12:49:15]
      owner = new_user()
      site = new_site(owner: owner)

      session1 = 111
      session2 = 222
      session3 = 333
      session4 = 444
      session5 = 555
      session6 = 666

      populate_stats(site, [
        # session 1 starts outside of query range
        build(:pageview, user_id: session1, timestamp: ~N[2025-10-19 11:00:00]),
        # session 1 continues within query range
        build(:pageview, user_id: session1, timestamp: ~N[2025-10-20 12:00:00]),
        # session 1 ends outside of query range
        build(:pageview, user_id: session1, timestamp: ~N[2025-10-20 13:00:00]),
        # session 2 starts within query range
        build(:pageview, user_id: session2, timestamp: ~N[2025-10-20 12:05:00]),
        # session 3 starts the day before, still within query range
        build(:pageview, user_id: session3, timestamp: ~N[2025-10-19 12:51:00]),
        # session 4 crosses time slot per hour boundaries
        build(:pageview, user_id: session4, timestamp: ~N[2025-10-19 11:50:00]),
        build(:pageview, user_id: session4, timestamp: ~N[2025-10-19 12:10:00]),
        build(:pageview, user_id: session4, timestamp: ~N[2025-10-19 12:30:00]),
        build(:pageview, user_id: session4, timestamp: ~N[2025-10-19 12:51:00]),
        build(:pageview, user_id: session4, timestamp: ~N[2025-10-19 13:01:00]),
        # session 5 should never appear
        build(:pageview, user_id: session5, timestamp: ~N[2025-10-19 12:48:00]),
        # session 6 starts outside of the query range
        build(:pageview, user_id: session6, timestamp: ~N[2025-10-19 12:00:00]),
        build(:pageview, user_id: session6, timestamp: ~N[2025-10-19 12:55:00])
      ])

      view = new_consolidated_view(team_of(owner))

      result = Plausible.Stats.ConsolidatedView.overview_24h(view, fixed_now)

      expected_non_zero_intervals = [
        {~N[2025-10-19 12:00:00], 3},
        {~N[2025-10-19 13:00:00], 1},
        {~N[2025-10-20 12:00:00], 2}
      ]

      assert %{
               visitors: 5,
               intervals: consolidated_intervals
             } = result

      result_individual =
        Plausible.Stats.Clickhouse.last_24h_visitors_hourly_intervals([site], fixed_now)[
          site.domain
        ]

      assert %{
               visitors: 5,
               intervals: individual_intervals
             } = result_individual

      assert length(consolidated_intervals) == length(individual_intervals)

      consolidated_result = filter_only_non_zero_intervals(consolidated_intervals)
      individual_result = filter_only_non_zero_intervals(individual_intervals)

      assert consolidated_result == expected_non_zero_intervals
      assert individual_result == expected_non_zero_intervals
    end

    defp filter_only_non_zero_intervals(intervals) do
      intervals
      |> Enum.filter(&(&1.visitors > 0))
      |> Enum.map(fn i -> {i.interval, i.visitors} end)
    end
  end
end
