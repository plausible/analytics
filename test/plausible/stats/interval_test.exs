defmodule Plausible.Stats.IntervalTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Interval

  test "default_for_period/1" do
    assert default_for_period("realtime") == "minute"
    assert default_for_period("day") == "hour"
    assert default_for_period("7d") == "date"
    assert default_for_period("12mo") == "month"
  end

  test "default_for_date_range/1" do
    assert default_for_date_range(Date.range(~D[2022-01-01], ~D[2023-01-01])) == "month"
    assert default_for_date_range(Date.range(~D[2022-01-01], ~D[2022-01-15])) == "date"
    assert default_for_date_range(Date.range(~D[2022-01-01], ~D[2022-01-01])) == "hour"
  end

  describe "valid_by_period/1" do
    test "for a newly created site" do
      site = build(:site, stats_start_date: Date.utc_today())

      assert valid_by_period(site: site) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "7d" => ["hour", "date"],
               "month" => ["date", "week"],
               "30d" => ["date", "week"],
               "6mo" => ["date", "week", "month"],
               "12mo" => ["date", "week", "month"],
               "year" => ["date", "week", "month"],
               "custom" => ["date", "week", "month"],
               "all" => ["date", "week", "month"]
             }
    end

    test "for a site with stats starting over 12m ago" do
      site = build(:site, stats_start_date: Timex.shift(Date.utc_today(), months: -13))

      assert valid_by_period(site: site) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "7d" => ["hour", "date"],
               "month" => ["date", "week"],
               "30d" => ["date", "week"],
               "6mo" => ["date", "week", "month"],
               "12mo" => ["date", "week", "month"],
               "year" => ["date", "week", "month"],
               "custom" => ["date", "week", "month"],
               "all" => ["week", "month"]
             }
    end

    test "for a query range exceeding 12m" do
      ago_13m = Timex.shift(Date.utc_today(), months: -13)
      site = build(:site, stats_start_date: ago_13m)

      assert valid_by_period(site: site, from: ago_13m, to: Date.utc_today()) == %{
               "realtime" => ["minute"],
               "day" => ["minute", "hour"],
               "7d" => ["hour", "date"],
               "month" => ["date", "week"],
               "30d" => ["date", "week"],
               "6mo" => ["date", "week", "month"],
               "12mo" => ["date", "week", "month"],
               "year" => ["date", "week", "month"],
               "custom" => ["week", "month"],
               "all" => ["week", "month"]
             }
    end
  end

  describe "valid_for_period/3" do
    test "common" do
      site = build(:site)
      assert valid_for_period?("month", "date", site: site)
      refute valid_for_period?("30d", "month", site: site)
      refute valid_for_period?("realtime", "week", site: site)
    end

    test "for a newly created site" do
      site = build(:site, stats_start_date: Date.utc_today())
      assert valid_for_period?("all", "date", site: site)

      assert valid_for_period?("custom", "date",
               site: site,
               from: ~D[2023-06-01],
               to: ~D[2023-07-01]
             )

      assert valid_for_period?("custom", "date",
               site: site,
               to: ~D[2023-06-01],
               from: ~D[2023-07-01]
             )
    end

    test "for a newly created site with >12m range" do
      site = build(:site, stats_start_date: Date.utc_today())
      assert valid_for_period?("all", "date", site: site)

      refute valid_for_period?("custom", "date",
               site: site,
               from: ~D[2012-06-01],
               to: ~D[2023-07-01]
             )

      refute valid_for_period?("custom", "date",
               site: site,
               to: ~D[2012-06-01],
               from: ~D[2023-07-01]
             )
    end

    test "for a site with stats starting over 12m ago" do
      site = build(:site, stats_start_date: Timex.shift(Date.utc_today(), months: -13))
      refute valid_for_period?("all", "date", site: site)

      assert valid_for_period?("custom", "date",
               site: site,
               from: ~D[2023-06-01],
               to: ~D[2023-07-01]
             )
    end
  end
end
