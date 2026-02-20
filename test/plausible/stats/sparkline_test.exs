defmodule Plausible.Stats.SparklineTest do
  use Plausible.DataCase, async: true

  alias Plausible.Stats.Sparkline

  describe "parallel_overview" do
    test "returns no data on no sites" do
      assert Sparkline.parallel_overview([]) == %{}
    end

    test "returns empty intervals placeholder on no clickhouse stats" do
      now = ~N[2023-10-26 10:00:15]

      site = new_site()
      domain = site.domain

      assert %{
               ^domain => %{
                 visitors: 0,
                 pageviews: 0,
                 pageviews_change: 0,
                 views_per_visit: +0.0,
                 views_per_visit_change: 0,
                 visitors_change: 0,
                 visits: 0,
                 visits_change: 0,
                 intervals: intervals
               }
             } =
               Sparkline.parallel_overview(
                 [site],
                 now
               )

      assert intervals == [
               %{interval: "2023-10-25 10:00:00", visitors: 0},
               %{interval: "2023-10-25 11:00:00", visitors: 0},
               %{interval: "2023-10-25 12:00:00", visitors: 0},
               %{interval: "2023-10-25 13:00:00", visitors: 0},
               %{interval: "2023-10-25 14:00:00", visitors: 0},
               %{interval: "2023-10-25 15:00:00", visitors: 0},
               %{interval: "2023-10-25 16:00:00", visitors: 0},
               %{interval: "2023-10-25 17:00:00", visitors: 0},
               %{interval: "2023-10-25 18:00:00", visitors: 0},
               %{interval: "2023-10-25 19:00:00", visitors: 0},
               %{interval: "2023-10-25 20:00:00", visitors: 0},
               %{interval: "2023-10-25 21:00:00", visitors: 0},
               %{interval: "2023-10-25 22:00:00", visitors: 0},
               %{interval: "2023-10-25 23:00:00", visitors: 0},
               %{interval: "2023-10-26 00:00:00", visitors: 0},
               %{interval: "2023-10-26 01:00:00", visitors: 0},
               %{interval: "2023-10-26 02:00:00", visitors: 0},
               %{interval: "2023-10-26 03:00:00", visitors: 0},
               %{interval: "2023-10-26 04:00:00", visitors: 0},
               %{interval: "2023-10-26 05:00:00", visitors: 0},
               %{interval: "2023-10-26 06:00:00", visitors: 0},
               %{interval: "2023-10-26 07:00:00", visitors: 0},
               %{interval: "2023-10-26 08:00:00", visitors: 0},
               %{interval: "2023-10-26 09:00:00", visitors: 0},
               %{interval: "2023-10-26 10:00:00", visitors: 0}
             ]

      assert intervals == Sparkline.empty_24h_intervals(now)
    end

    test "returns clickhouse data merged with placeholder" do
      now = ~U[2023-10-26 10:00:15Z]

      site = new_site()

      user_id = 111

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 11:01:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:01:00]),
        build(:pageview, timestamp: ~N[2023-10-26 10:00:14])
      ])

      assert %{
               visitors: 5,
               visitors_change: 100,
               intervals: [
                 %{interval: "2023-10-25 10:00:00", visitors: 0},
                 %{interval: "2023-10-25 11:00:00", visitors: 1},
                 %{interval: "2023-10-25 12:00:00", visitors: 0},
                 %{interval: "2023-10-25 13:00:00", visitors: 2},
                 %{interval: "2023-10-25 14:00:00", visitors: 0},
                 %{interval: "2023-10-25 15:00:00", visitors: 1},
                 %{interval: "2023-10-25 16:00:00", visitors: 0},
                 %{interval: "2023-10-25 17:00:00", visitors: 0},
                 %{interval: "2023-10-25 18:00:00", visitors: 0},
                 %{interval: "2023-10-25 19:00:00", visitors: 0},
                 %{interval: "2023-10-25 20:00:00", visitors: 0},
                 %{interval: "2023-10-25 21:00:00", visitors: 0},
                 %{interval: "2023-10-25 22:00:00", visitors: 0},
                 %{interval: "2023-10-25 23:00:00", visitors: 0},
                 %{interval: "2023-10-26 00:00:00", visitors: 0},
                 %{interval: "2023-10-26 01:00:00", visitors: 0},
                 %{interval: "2023-10-26 02:00:00", visitors: 0},
                 %{interval: "2023-10-26 03:00:00", visitors: 0},
                 %{interval: "2023-10-26 04:00:00", visitors: 0},
                 %{interval: "2023-10-26 05:00:00", visitors: 0},
                 %{interval: "2023-10-26 06:00:00", visitors: 0},
                 %{interval: "2023-10-26 07:00:00", visitors: 0},
                 %{interval: "2023-10-26 08:00:00", visitors: 0},
                 %{interval: "2023-10-26 09:00:00", visitors: 0},
                 %{interval: "2023-10-26 10:00:00", visitors: 1}
               ]
             } = Sparkline.parallel_overview([site], now)[site.domain]
    end

    test "ignores visits before native stats start time (after reset)" do
      now = ~N[2023-10-26 10:00:15]
      site1 = insert(:site, native_stats_start_at: ~N[2023-10-25 14:15:00])
      site2 = insert(:site, native_stats_start_at: ~N[2023-10-23 12:00:00])

      user_id1 = 111
      user_id2 = 222

      populate_stats(site1, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id1, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id1, timestamp: ~N[2023-10-25 15:01:00])
      ])

      populate_stats(site2, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id2, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id2, timestamp: ~N[2023-10-25 15:01:00])
      ])

      assert %{
               visitors_change: 100,
               visitors: 1,
               intervals: [
                 %{interval: "2023-10-25 10:00:00", visitors: 0},
                 %{interval: "2023-10-25 11:00:00", visitors: 0},
                 %{interval: "2023-10-25 12:00:00", visitors: 0},
                 %{interval: "2023-10-25 13:00:00", visitors: 0},
                 %{interval: "2023-10-25 14:00:00", visitors: 0},
                 %{interval: "2023-10-25 15:00:00", visitors: 1},
                 %{interval: "2023-10-25 16:00:00", visitors: 0},
                 %{interval: "2023-10-25 17:00:00", visitors: 0},
                 %{interval: "2023-10-25 18:00:00", visitors: 0},
                 %{interval: "2023-10-25 19:00:00", visitors: 0},
                 %{interval: "2023-10-25 20:00:00", visitors: 0},
                 %{interval: "2023-10-25 21:00:00", visitors: 0},
                 %{interval: "2023-10-25 22:00:00", visitors: 0},
                 %{interval: "2023-10-25 23:00:00", visitors: 0},
                 %{interval: "2023-10-26 00:00:00", visitors: 0},
                 %{interval: "2023-10-26 01:00:00", visitors: 0},
                 %{interval: "2023-10-26 02:00:00", visitors: 0},
                 %{interval: "2023-10-26 03:00:00", visitors: 0},
                 %{interval: "2023-10-26 04:00:00", visitors: 0},
                 %{interval: "2023-10-26 05:00:00", visitors: 0},
                 %{interval: "2023-10-26 06:00:00", visitors: 0},
                 %{interval: "2023-10-26 07:00:00", visitors: 0},
                 %{interval: "2023-10-26 08:00:00", visitors: 0},
                 %{interval: "2023-10-26 09:00:00", visitors: 0},
                 %{interval: "2023-10-26 10:00:00", visitors: 0}
               ]
             } = Sparkline.parallel_overview([site1], now)[site1.domain]

      assert %{
               visitors_change: 100,
               visitors: 3,
               intervals: [
                 %{interval: "2023-10-25 10:00:00", visitors: 0},
                 %{interval: "2023-10-25 11:00:00", visitors: 0},
                 %{interval: "2023-10-25 12:00:00", visitors: 0},
                 %{interval: "2023-10-25 13:00:00", visitors: 2},
                 %{interval: "2023-10-25 14:00:00", visitors: 0},
                 %{interval: "2023-10-25 15:00:00", visitors: 1},
                 %{interval: "2023-10-25 16:00:00", visitors: 0},
                 %{interval: "2023-10-25 17:00:00", visitors: 0},
                 %{interval: "2023-10-25 18:00:00", visitors: 0},
                 %{interval: "2023-10-25 19:00:00", visitors: 0},
                 %{interval: "2023-10-25 20:00:00", visitors: 0},
                 %{interval: "2023-10-25 21:00:00", visitors: 0},
                 %{interval: "2023-10-25 22:00:00", visitors: 0},
                 %{interval: "2023-10-25 23:00:00", visitors: 0},
                 %{interval: "2023-10-26 00:00:00", visitors: 0},
                 %{interval: "2023-10-26 01:00:00", visitors: 0},
                 %{interval: "2023-10-26 02:00:00", visitors: 0},
                 %{interval: "2023-10-26 03:00:00", visitors: 0},
                 %{interval: "2023-10-26 04:00:00", visitors: 0},
                 %{interval: "2023-10-26 05:00:00", visitors: 0},
                 %{interval: "2023-10-26 06:00:00", visitors: 0},
                 %{interval: "2023-10-26 07:00:00", visitors: 0},
                 %{interval: "2023-10-26 08:00:00", visitors: 0},
                 %{interval: "2023-10-26 09:00:00", visitors: 0},
                 %{interval: "2023-10-26 10:00:00", visitors: 0}
               ]
             } = Sparkline.parallel_overview([site2], now)[site2.domain]
    end

    test "returns clickhouse data merged with placeholder for multiple sites" do
      now = ~N[2023-10-26 10:00:15]
      site1 = new_site()
      site2 = new_site()
      site3 = new_site()

      user_id = 111

      populate_stats(site1, [
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 13:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 13:01:00]),
        build(:pageview, timestamp: ~N[2023-10-25 15:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      populate_stats(site2, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:01:00])
      ])

      assert result =
               Sparkline.parallel_overview([site1, site2, site3], now)

      assert result[site1.domain].visitors == 3
      assert result[site1.domain].visitors_change == 100
      assert result[site2.domain].visitors == 3
      assert result[site2.domain].visitors_change == 100
      assert result[site3.domain].visitors == 0
      assert result[site3.domain].visitors_change == 0

      find_interval = fn result, domain, interval ->
        Enum.find(result[domain].intervals, &(&1.interval == interval))
      end

      assert find_interval.(result, site1.domain, "2023-10-25 13:00:00").visitors == 1
      assert find_interval.(result, site1.domain, "2023-10-25 15:00:00").visitors == 2
      assert find_interval.(result, site2.domain, "2023-10-25 13:00:00").visitors == 2
      assert find_interval.(result, site2.domain, "2023-10-25 15:00:00").visitors == 1
    end

    test "returns calculated change" do
      now = ~N[2023-10-26 10:00:15]
      site = new_site()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-24 11:58:00]),
        build(:pageview, timestamp: ~N[2023-10-24 12:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00])
      ])

      assert %{
               visitors_change: 50,
               visitors: 3
             } = Sparkline.parallel_overview([site], now)[site.domain]
    end

    test "calculates uniques correctly across hour boundaries" do
      now = ~N[2023-10-26 10:00:15]
      site = new_site()

      user_id = 111

      populate_stats(site, [
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:59:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 16:00:00])
      ])

      result = Sparkline.parallel_overview([site], now)[site.domain]
      assert result[:visitors] == 1
    end

    test "another one" do
      now = ~N[2023-10-26 10:00:15]
      site = new_site()

      user_id = 111

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 16:00:00])
      ])

      assert %{
               visitors_change: 100,
               visitors: 3,
               intervals: [
                 %{interval: "2023-10-25 10:00:00", visitors: 0},
                 %{interval: "2023-10-25 11:00:00", visitors: 0},
                 %{interval: "2023-10-25 12:00:00", visitors: 0},
                 %{interval: "2023-10-25 13:00:00", visitors: 2},
                 %{interval: "2023-10-25 14:00:00", visitors: 0},
                 %{interval: "2023-10-25 15:00:00", visitors: 1},
                 %{interval: "2023-10-25 16:00:00", visitors: 1},
                 %{interval: "2023-10-25 17:00:00", visitors: 0},
                 %{interval: "2023-10-25 18:00:00", visitors: 0},
                 %{interval: "2023-10-25 19:00:00", visitors: 0},
                 %{interval: "2023-10-25 20:00:00", visitors: 0},
                 %{interval: "2023-10-25 21:00:00", visitors: 0},
                 %{interval: "2023-10-25 22:00:00", visitors: 0},
                 %{interval: "2023-10-25 23:00:00", visitors: 0},
                 %{interval: "2023-10-26 00:00:00", visitors: 0},
                 %{interval: "2023-10-26 01:00:00", visitors: 0},
                 %{interval: "2023-10-26 02:00:00", visitors: 0},
                 %{interval: "2023-10-26 03:00:00", visitors: 0},
                 %{interval: "2023-10-26 04:00:00", visitors: 0},
                 %{interval: "2023-10-26 05:00:00", visitors: 0},
                 %{interval: "2023-10-26 06:00:00", visitors: 0},
                 %{interval: "2023-10-26 07:00:00", visitors: 0},
                 %{interval: "2023-10-26 08:00:00", visitors: 0},
                 %{interval: "2023-10-26 09:00:00", visitors: 0},
                 %{interval: "2023-10-26 10:00:00", visitors: 0}
               ]
             } = Sparkline.parallel_overview([site], now)[site.domain]
    end

    test "excludes engagement events from visitor counts" do
      site = new_site()
      now = ~N[2025-10-20 12:49:15]

      populate_stats(site, [
        build(:pageview, user_id: 111, timestamp: ~N[2025-10-20 12:00:00]),
        build(:pageview, user_id: 222, timestamp: ~N[2025-10-20 10:50:00]),
        build(:engagement,
          user_id: 222,
          pathname: "/blog",
          timestamp: ~N[2025-10-20 10:50:01],
          scroll_depth: 20,
          engagement_time: 50_000
        )
      ])

      result = Sparkline.parallel_overview([site], now)[site.domain]

      assert %{visitors: 2} = result
    end
  end
end
