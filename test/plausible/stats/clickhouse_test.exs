defmodule Plausible.Stats.ClickhouseTest do
  use Plausible.DataCase, async: true
  import Plausible.TestUtils
  alias Plausible.Stats.Clickhouse

  describe "last_24_visitors_hourly_intervals/1" do
    test "returns no data on no sites" do
      assert Clickhouse.last_24h_visitors_hourly_intervals([]) == %{}
    end

    test "returns empty intervals placeholder on no clickhouse stats" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site = insert(:site)
      domain = site.domain

      assert Clickhouse.last_24h_visitors_hourly_intervals(
               [site],
               fixed_now
             ) ==
               %{
                 domain => %{
                   change: 0,
                   visitors: 0,
                   intervals: [
                     %{interval: ~N[2023-10-25 11:00:00], visitors: 0},
                     %{interval: ~N[2023-10-25 12:00:00], visitors: 0},
                     %{interval: ~N[2023-10-25 13:00:00], visitors: 0},
                     %{interval: ~N[2023-10-25 14:00:00], visitors: 0},
                     %{interval: ~N[2023-10-25 15:00:00], visitors: 0},
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
                     %{interval: ~N[2023-10-26 10:00:00], visitors: 0},
                     %{interval: ~N[2023-10-26 11:00:00], visitors: 0}
                   ]
                 }
               }
    end

    test "returns clickhouse data merged with placeholder" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site = insert(:site)

      user_id = 111

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:01:00])
      ])

      assert %{
               change: 100,
               visitors: 3,
               intervals: [
                 %{interval: ~N[2023-10-25 11:00:00], visitors: 0},
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
                 %{interval: ~N[2023-10-26 10:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 11:00:00], visitors: 0}
               ]
             } = Clickhouse.last_24h_visitors_hourly_intervals([site], fixed_now)[site.domain]
    end

    test "ignores visits before native stats start time (after reset)" do
      fixed_now = ~N[2023-10-26 10:00:15]
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
               change: 100,
               visitors: 1,
               intervals: [
                 %{interval: ~N[2023-10-25 11:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 12:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 13:00:00], visitors: 0},
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
                 %{interval: ~N[2023-10-26 10:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 11:00:00], visitors: 0}
               ]
             } = Clickhouse.last_24h_visitors_hourly_intervals([site1], fixed_now)[site1.domain]

      assert %{
               change: 100,
               visitors: 3,
               intervals: [
                 %{interval: ~N[2023-10-25 11:00:00], visitors: 0},
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
                 %{interval: ~N[2023-10-26 10:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 11:00:00], visitors: 0}
               ]
             } = Clickhouse.last_24h_visitors_hourly_intervals([site2], fixed_now)[site2.domain]
    end

    test "returns clickhouse data merged with placeholder for multiple sites" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site1 = insert(:site)
      site2 = insert(:site)
      site3 = insert(:site)

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
               Clickhouse.last_24h_visitors_hourly_intervals([site1, site2, site3], fixed_now)

      assert result[site1.domain].visitors == 3
      assert result[site1.domain].change == 100
      assert result[site2.domain].visitors == 3
      assert result[site2.domain].change == 100
      assert result[site3.domain].visitors == 0
      assert result[site3.domain].change == 0

      find_interval = fn result, domain, interval ->
        Enum.find(result[domain].intervals, &(&1.interval == interval))
      end

      assert find_interval.(result, site1.domain, ~N[2023-10-25 13:00:00]).visitors == 1
      assert find_interval.(result, site1.domain, ~N[2023-10-25 15:00:00]).visitors == 2
      assert find_interval.(result, site2.domain, ~N[2023-10-25 13:00:00]).visitors == 2
      assert find_interval.(result, site2.domain, ~N[2023-10-25 15:00:00]).visitors == 1
    end

    test "returns calculated change" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-24 11:58:00]),
        build(:pageview, timestamp: ~N[2023-10-24 12:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00])
      ])

      assert %{
               change: 50,
               visitors: 3
             } = Clickhouse.last_24h_visitors_hourly_intervals([site], fixed_now)[site.domain]
    end

    test "calculates uniques correctly across hour boundaries" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site = insert(:site)

      user_id = 111

      populate_stats(site, [
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:59:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 16:00:00])
      ])

      result = Clickhouse.last_24h_visitors_hourly_intervals([site], fixed_now)[site.domain]
      assert result[:visitors] == 1
    end

    test "another one" do
      fixed_now = ~N[2023-10-26 10:00:15]
      site = insert(:site)

      user_id = 111

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 13:59:00]),
        build(:pageview, timestamp: ~N[2023-10-25 13:58:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 15:00:00]),
        build(:pageview, user_id: user_id, timestamp: ~N[2023-10-25 16:00:00])
      ])

      assert %{
               change: 100,
               visitors: 3,
               intervals: [
                 %{interval: ~N[2023-10-25 11:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 12:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 13:00:00], visitors: 2},
                 %{interval: ~N[2023-10-25 14:00:00], visitors: 0},
                 %{interval: ~N[2023-10-25 15:00:00], visitors: 1},
                 %{interval: ~N[2023-10-25 16:00:00], visitors: 1},
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
                 %{interval: ~N[2023-10-26 10:00:00], visitors: 0},
                 %{interval: ~N[2023-10-26 11:00:00], visitors: 0}
               ]
             } = Clickhouse.last_24h_visitors_hourly_intervals([site], fixed_now)[site.domain]
    end
  end

  describe "imported_pageview_counts/1" do
    test "gets pageview counts for each of sites' imports" do
      site = insert(:site)

      import1 = insert(:site_import, site: site)
      import2 = insert(:site_import, site: site)

      # legacy import
      populate_stats(site, [
        build(:imported_visitors, pageviews: 5),
        build(:imported_visitors, pageviews: 6)
      ])

      populate_stats(site, import1.id, [
        build(:imported_visitors, pageviews: 6),
        build(:imported_visitors, pageviews: 8)
      ])

      populate_stats(site, import2.id, [
        build(:imported_visitors, pageviews: 7),
        build(:imported_visitors, pageviews: 13)
      ])

      pageview_counts = Clickhouse.imported_pageview_counts(site)

      assert map_size(pageview_counts) == 3
      assert pageview_counts[0] == 11
      assert pageview_counts[import1.id] == 14
      assert pageview_counts[import2.id] == 20
    end
  end
end
