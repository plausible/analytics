defmodule Plausible.Stats.QueryPeriodTest do
  use ExUnit.Case, async: true

  alias Plausible.Stats.{DateTimeRange, QueryPeriod}

  doctest QueryPeriod, import: true

  @now_irrelevant ~U[2999-01-01 00:00:00Z]

  describe "build_datetime_range/4" do
    test "the day period truncates at \"now\" when the date is today" do
      now = ~U[2026-05-05 12:30:00Z]
      range = QueryPeriod.build_datetime_range(:day, "Etc/UTC", ~D[2026-05-05], now)
      assert range.first == ~U[2026-05-05 00:00:00Z]
      assert range.last == now
    end

    test "a custom date range in Tallinn correctly spans a DST transition (EET to EEST)" do
      range =
        QueryPeriod.build_datetime_range(
          {:date_range, ~D[2026-03-15], ~D[2026-04-15]},
          "Europe/Tallinn",
          ~D[2026-04-01],
          @now_irrelevant
        )

      assert DateTime.to_iso8601(range.first) == "2026-03-15T00:00:00+02:00"
      assert DateTime.to_iso8601(range.last) == "2026-04-15T23:59:59+03:00"
    end

    for timezone <- ["Etc/UTC", "America/New_York", "Europe/Tallinn", "Asia/Tokyo"] do
      test "the last 24 hours window covers the same UTC moments regardless of timezone (#{timezone})" do
        now = ~U[2026-05-05 12:30:00Z]

        utc_range =
          QueryPeriod.build_datetime_range(:"24h", unquote(timezone), ~D[2026-05-05], now)
          |> DateTimeRange.to_timezone("Etc/UTC")

        assert utc_range.first == ~U[2026-05-04 12:30:00Z]
        assert utc_range.last == now
      end
    end

    test "the month period spans 28 days in a non-leap-year February" do
      range =
        QueryPeriod.build_datetime_range(:month, "Etc/UTC", ~D[2026-02-10], @now_irrelevant)

      assert range.first == ~U[2026-02-01 00:00:00Z]
      assert range.last == ~U[2026-02-28 23:59:59Z]
    end

    test "the month period spans 29 days in a leap-year February" do
      range =
        QueryPeriod.build_datetime_range(:month, "Etc/UTC", ~D[2024-02-10], @now_irrelevant)

      assert range.first == ~U[2024-02-01 00:00:00Z]
      assert range.last == ~U[2024-02-29 23:59:59Z]
    end

    test "the year period still ends December 31 in a leap year" do
      range =
        QueryPeriod.build_datetime_range(:year, "Etc/UTC", ~D[2024-06-15], @now_irrelevant)

      assert range.first == ~U[2024-01-01 00:00:00Z]
      assert range.last == ~U[2024-12-31 23:59:59Z]
    end
  end

  describe "build_range_for_site/4" do
    test "anchors the range in the site's timezone" do
      site = %Plausible.Site{timezone: "America/New_York"}

      range = QueryPeriod.build_range_for_site(:day, site, ~D[2026-05-04], @now_irrelevant)

      assert range.first.time_zone == "America/New_York"
      assert range.last.time_zone == "America/New_York"
      assert DateTime.to_iso8601(range.first) == "2026-05-04T00:00:00-04:00"
      assert DateTime.to_iso8601(range.last) == "2026-05-04T23:59:59-04:00"
    end

    test "the \"all\" period starts at the site's stats start date" do
      site = %Plausible.Site{timezone: "Etc/UTC", stats_start_date: ~D[2024-01-15]}

      range = QueryPeriod.build_range_for_site(:all, site, ~D[2026-05-05], @now_irrelevant)

      assert DateTime.to_date(range.first) == ~D[2024-01-15]
      assert DateTime.to_date(range.last) == ~D[2026-05-05]
    end

    test "without a relative date, uses today in the site's timezone" do
      site = %Plausible.Site{timezone: "Etc/UTC"}
      now = ~U[2026-05-05 12:30:00Z]

      range = QueryPeriod.build_range_for_site(:day, site, nil, now)

      assert range.first == ~U[2026-05-05 00:00:00Z]
      assert range.last == now
    end

    test "a Tallinn site's month range is anchored to Tallinn local time" do
      site = %Plausible.Site{timezone: "Europe/Tallinn"}

      range = QueryPeriod.build_range_for_site(:month, site, ~D[2026-01-15], @now_irrelevant)

      assert range.first.time_zone == "Europe/Tallinn"
      assert range.last.time_zone == "Europe/Tallinn"
      assert DateTime.to_iso8601(range.first) == "2026-01-01T00:00:00+02:00"
      assert DateTime.to_iso8601(range.last) == "2026-01-31T23:59:59+02:00"
    end
  end

  describe "resolve_input_date_range/3" do
    test "the \"all\" period resolves to a concrete date range using the site's stats start date" do
      site = %Plausible.Site{stats_start_date: ~D[2024-01-15]}

      assert QueryPeriod.resolve_input_date_range(:all, site, ~D[2026-05-05]) ==
               {:date_range, ~D[2024-01-15], ~D[2026-05-05]}
    end

    test "other periods pass through unchanged" do
      site = %Plausible.Site{stats_start_date: ~D[2024-01-15]}

      assert QueryPeriod.resolve_input_date_range(:day, site, ~D[2026-05-05]) == :day

      assert QueryPeriod.resolve_input_date_range({:last_n_days, 7}, site, ~D[2026-05-05]) ==
               {:last_n_days, 7}

      assert QueryPeriod.resolve_input_date_range(:realtime, site, ~D[2026-05-05]) == :realtime
    end
  end
end
