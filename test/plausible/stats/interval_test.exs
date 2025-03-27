defmodule Plausible.Stats.IntervalTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Interval
  alias Plausible.Stats.DateTimeRange

  test "default_for_period/1" do
    assert default_for_period("realtime") == "minute"
    assert default_for_period("day") == "hour"
    assert default_for_period("7d") == "day"
    assert default_for_period("12mo") == "month"
  end

  test "default_for_date_range/1" do
    year = DateTimeRange.new!(~D[2022-01-01], ~D[2023-01-01], "UTC")
    fifteen_days = DateTimeRange.new!(~D[2022-01-01], ~D[2022-01-15], "UTC")
    day = DateTimeRange.new!(~D[2022-01-01], ~D[2022-01-01], "UTC")

    assert default_for_date_range(year) == "month"
    assert default_for_date_range(fifteen_days) == "day"
    assert default_for_date_range(day) == "hour"
  end

  describe "valid_by_period/1" do
    test "for a newly created site" do
      site = build(:site, stats_start_date: Date.utc_today())

      assert valid_by_period(site: site) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "month" => ["day", "week"],
               "7d" => ["hour", "day"],
               "28d" => ["day", "week"],
               "30d" => ["day", "week"],
               "90d" => ["day", "week", "month"],
               "6mo" => ["day", "week", "month"],
               "12mo" => ["day", "week", "month"],
               "year" => ["day", "week", "month"],
               "custom" => ["day", "week", "month"],
               "all" => ["day", "week", "month"]
             }
    end

    test "for a site with stats starting over 12m ago" do
      site = build(:site, stats_start_date: Timex.shift(Date.utc_today(), months: -13))

      assert valid_by_period(site: site) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "month" => ["day", "week"],
               "7d" => ["hour", "day"],
               "28d" => ["day", "week"],
               "30d" => ["day", "week"],
               "90d" => ["day", "week", "month"],
               "6mo" => ["day", "week", "month"],
               "12mo" => ["day", "week", "month"],
               "year" => ["day", "week", "month"],
               "custom" => ["day", "week", "month"],
               "all" => ["week", "month"]
             }
    end

    test "for a query range exceeding 12m" do
      ago_13m = Timex.shift(Date.utc_today(), months: -13)
      site = build(:site, stats_start_date: ago_13m)

      assert valid_by_period(site: site, from: ago_13m, to: Date.utc_today()) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "month" => ["day", "week"],
               "7d" => ["hour", "day"],
               "28d" => ["day", "week"],
               "30d" => ["day", "week"],
               "90d" => ["day", "week", "month"],
               "6mo" => ["day", "week", "month"],
               "12mo" => ["day", "week", "month"],
               "year" => ["day", "week", "month"],
               "custom" => ["week", "month"],
               "all" => ["week", "month"]
             }
    end
  end

  describe "valid_for_period/3" do
    test "common" do
      site = insert(:site)
      assert valid_for_period?("month", "day", site: site)
      refute valid_for_period?("30d", "month", site: site)
      refute valid_for_period?("realtime", "week", site: site)
    end

    test "for a newly created site" do
      site = build(:site, stats_start_date: Date.utc_today())
      assert valid_for_period?("all", "day", site: site)

      assert valid_for_period?("custom", "day",
               site: site,
               from: ~D[2023-06-01],
               to: ~D[2023-07-01]
             )

      assert valid_for_period?("custom", "day",
               site: site,
               to: ~D[2023-06-01],
               from: ~D[2023-07-01]
             )
    end

    test "for a newly created site with >12m range" do
      site = build(:site, stats_start_date: Date.utc_today())
      assert valid_for_period?("all", "day", site: site)

      refute valid_for_period?("custom", "day",
               site: site,
               from: ~D[2012-06-01],
               to: ~D[2023-07-01]
             )

      refute valid_for_period?("custom", "day",
               site: site,
               to: ~D[2012-06-01],
               from: ~D[2023-07-01]
             )
    end

    test "for a site with stats starting over 12m ago" do
      site = build(:site, stats_start_date: Timex.shift(Date.utc_today(), months: -13))
      refute valid_for_period?("all", "day", site: site)

      assert valid_for_period?("custom", "day",
               site: site,
               from: ~D[2023-06-01],
               to: ~D[2023-07-01]
             )
    end
  end
end
