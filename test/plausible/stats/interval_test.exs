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
      site = insert(:site)
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

  describe "time_labels/1" do
    test "with time:month dimension" do
      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-02-01])
             }) == [
               ~D[2022-01-01],
               ~D[2022-02-01]
             ]

      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               date_range: Date.range(~D[2022-01-01], ~D[2022-03-07])
             }) == [
               ~D[2022-01-01],
               ~D[2022-02-01],
               ~D[2022-03-01]
             ]
    end

    test "with time:day dimension" do
      assert time_labels(%{
               dimensions: ["time:day"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-02-02])
             }) == [
               ~D[2022-01-17],
               ~D[2022-01-18],
               ~D[2022-01-19],
               ~D[2022-01-20],
               ~D[2022-01-21],
               ~D[2022-01-22],
               ~D[2022-01-23],
               ~D[2022-01-24],
               ~D[2022-01-25],
               ~D[2022-01-26],
               ~D[2022-01-27],
               ~D[2022-01-28],
               ~D[2022-01-29],
               ~D[2022-01-30],
               ~D[2022-01-31],
               ~D[2022-02-01],
               ~D[2022-02-02]
             ]
    end

    test "with time:hour dimension" do
      assert time_labels(%{
               dimensions: ["time:hour"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-01-17])
             }) == [
               ~U[2022-01-17 00:00:00Z],
               ~U[2022-01-17 01:00:00Z],
               ~U[2022-01-17 02:00:00Z],
               ~U[2022-01-17 03:00:00Z],
               ~U[2022-01-17 04:00:00Z],
               ~U[2022-01-17 05:00:00Z],
               ~U[2022-01-17 06:00:00Z],
               ~U[2022-01-17 07:00:00Z],
               ~U[2022-01-17 08:00:00Z],
               ~U[2022-01-17 09:00:00Z],
               ~U[2022-01-17 10:00:00Z],
               ~U[2022-01-17 11:00:00Z],
               ~U[2022-01-17 12:00:00Z],
               ~U[2022-01-17 13:00:00Z],
               ~U[2022-01-17 14:00:00Z],
               ~U[2022-01-17 15:00:00Z],
               ~U[2022-01-17 16:00:00Z],
               ~U[2022-01-17 17:00:00Z],
               ~U[2022-01-17 18:00:00Z],
               ~U[2022-01-17 19:00:00Z],
               ~U[2022-01-17 20:00:00Z],
               ~U[2022-01-17 21:00:00Z],
               ~U[2022-01-17 22:00:00Z],
               ~U[2022-01-17 23:00:00Z]
             ]

      assert time_labels(%{
               dimensions: ["time:hour"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-01-18])
             }) == [
               ~U[2022-01-17 00:00:00Z],
               ~U[2022-01-17 01:00:00Z],
               ~U[2022-01-17 02:00:00Z],
               ~U[2022-01-17 03:00:00Z],
               ~U[2022-01-17 04:00:00Z],
               ~U[2022-01-17 05:00:00Z],
               ~U[2022-01-17 06:00:00Z],
               ~U[2022-01-17 07:00:00Z],
               ~U[2022-01-17 08:00:00Z],
               ~U[2022-01-17 09:00:00Z],
               ~U[2022-01-17 10:00:00Z],
               ~U[2022-01-17 11:00:00Z],
               ~U[2022-01-17 12:00:00Z],
               ~U[2022-01-17 13:00:00Z],
               ~U[2022-01-17 14:00:00Z],
               ~U[2022-01-17 15:00:00Z],
               ~U[2022-01-17 16:00:00Z],
               ~U[2022-01-17 17:00:00Z],
               ~U[2022-01-17 18:00:00Z],
               ~U[2022-01-17 19:00:00Z],
               ~U[2022-01-17 20:00:00Z],
               ~U[2022-01-17 21:00:00Z],
               ~U[2022-01-17 22:00:00Z],
               ~U[2022-01-17 23:00:00Z],
               ~U[2022-01-18 00:00:00Z],
               ~U[2022-01-18 01:00:00Z],
               ~U[2022-01-18 02:00:00Z],
               ~U[2022-01-18 03:00:00Z],
               ~U[2022-01-18 04:00:00Z],
               ~U[2022-01-18 05:00:00Z],
               ~U[2022-01-18 06:00:00Z],
               ~U[2022-01-18 07:00:00Z],
               ~U[2022-01-18 08:00:00Z],
               ~U[2022-01-18 09:00:00Z],
               ~U[2022-01-18 10:00:00Z],
               ~U[2022-01-18 11:00:00Z],
               ~U[2022-01-18 12:00:00Z],
               ~U[2022-01-18 13:00:00Z],
               ~U[2022-01-18 14:00:00Z],
               ~U[2022-01-18 15:00:00Z],
               ~U[2022-01-18 16:00:00Z],
               ~U[2022-01-18 17:00:00Z],
               ~U[2022-01-18 18:00:00Z],
               ~U[2022-01-18 19:00:00Z],
               ~U[2022-01-18 20:00:00Z],
               ~U[2022-01-18 21:00:00Z],
               ~U[2022-01-18 22:00:00Z],
               ~U[2022-01-18 23:00:00Z]
             ]
    end
  end
end
