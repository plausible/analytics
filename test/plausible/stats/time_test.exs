defmodule Plausible.Stats.TimeTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Time
  alias Plausible.Stats.DateTimeRange

  @now DateTime.utc_now(:second)

  describe "partial_time_labels/2" do
    test "returns today as partial_time_label for time:day when today is still incomplete" do
      now = ~U[2023-03-01 14:00:00Z]

      assert partial_time_labels(["2023-03-01"], %{
               dimensions: ["time:day"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 00:00:00Z], now),
               now: now,
               timezone: "UTC"
             }) == ["2023-03-01"]
    end

    test "time_label of today is not partial when it's 23:59:59" do
      now = ~U[2023-03-01 23:59:59Z]

      assert partial_time_labels(["2023-03-01"], %{
               dimensions: ["time:day"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 00:00:00Z], now),
               now: now,
               timezone: "UTC"
             }) == []
    end

    test "returns current hour as partial time label when it's incomplete" do
      now = ~U[2023-03-01 12:30:00Z]

      assert partial_time_labels(["2023-03-01 12:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:00:00Z], now),
               now: now,
               timezone: "UTC"
             }) == ["2023-03-01 12:00:00"]
    end

    test "current hour is not partial when query.now is the last second of the hour" do
      now = ~U[2023-03-01 12:59:59Z]

      assert partial_time_labels(["2023-03-01 12:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:00:00Z], now),
               now: now,
               timezone: "UTC"
             }) == []
    end

    test "returns current minute as partial time label when it's incomplete" do
      now = ~U[2023-03-01 12:30:30Z]

      assert partial_time_labels(["2023-03-01 12:30:00"], %{
               dimensions: ["time:minute"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:30:00Z], now),
               now: now,
               timezone: "UTC"
             }) == ["2023-03-01 12:30:00"]
    end

    test "current minute is not partial when query.now is the last second of the minute" do
      now = ~U[2023-03-01 12:30:59Z]

      assert partial_time_labels(["2023-03-01 12:30:00"], %{
               dimensions: ["time:minute"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:30:00Z], now),
               now: now,
               timezone: "UTC"
             }) == []
    end

    test "first bucket is partial when query range starts mid-bucket (e.g. last 24h)" do
      # time:day: range starts at 12:30, so the first day only has half a day of data
      now = ~U[2023-03-02 12:30:00Z]

      assert partial_time_labels(["2023-03-01", "2023-03-02"], %{
               dimensions: ["time:day"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:30:00Z], now),
               now: now,
               timezone: "UTC"
             }) == ["2023-03-01", "2023-03-02"]

      # time:hour: range starts at 12:30, so the first hour only has 30 minutes of data
      now = ~U[2023-03-01 13:30:00Z]

      assert partial_time_labels(["2023-03-01 12:00:00", "2023-03-01 13:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 12:30:00Z], now),
               now: now,
               timezone: "UTC"
             }) == ["2023-03-01 12:00:00", "2023-03-01 13:00:00"]
    end

    test "handles timezone with non-whole-hour UTC offset (IST, UTC+05:30)" do
      # 13:30 UTC = 19:00 IST (range starts exactly on the hour, so first bucket is not partial)
      # 14:00 UTC = 19:30 IST, so the 19:00 IST hour is still in progress
      now = ~U[2023-03-01 14:00:00Z]

      assert partial_time_labels(["2023-03-01 19:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 13:30:00Z], now),
               now: now,
               timezone: "Asia/Kolkata"
             }) == ["2023-03-01 19:00:00"]

      # 14:30 UTC = 20:00 IST, so the 19:00 IST hour is now complete
      now = ~U[2023-03-01 14:30:00Z]

      assert partial_time_labels(["2023-03-01 19:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2023-03-01 13:30:00Z], now),
               now: now,
               timezone: "Asia/Kolkata"
             }) == []
    end

    test "handles DST transition (America/New_York, UTC-04:00 -> UTC-05:00)" do
      # Clocks fall back 02:00 -> 01:00, so 01:xx occurs twice.
      # 05:00 UTC = 01:00 EDT (first occurrence, UTC-4)
      # 06:00 UTC = 01:00 EST (second occurrence, UTC-5)
      now = ~U[2026-11-01 06:30:00Z]

      # 06:30 UTC = 01:30 EST
      assert partial_time_labels(["2026-11-01 01:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2026-11-01 06:00:00Z], now),
               now: now,
               timezone: "America/New_York"
             }) == ["2026-11-01 01:00:00"]

      # 06:59:59 UTC = 01:59:59 EST
      now = ~U[2026-11-01 06:59:59Z]

      assert partial_time_labels(["2026-11-01 01:00:00"], %{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~U[2026-11-01 06:00:00Z], now),
               now: now,
               timezone: "America/New_York"
             }) == []
    end

    test "first month bucket is partial if date range start is one second after actual month start" do
      assert partial_time_labels(["2023-03-01"], %{
               dimensions: ["time:month"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-01 00:00:01Z], ~U[2023-03-31 23:59:59Z]),
               now: @now,
               timezone: "UTC"
             }) == ["2023-03-01"]
    end

    test "last month bucket is partial if date range end is one second before actual month end" do
      assert partial_time_labels(["2023-03-01"], %{
               dimensions: ["time:month"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-01 00:00:00Z], ~U[2023-03-31 23:59:58Z]),
               now: @now,
               timezone: "UTC"
             }) == ["2023-03-01"]
    end

    test "a month bucket is not partial if date range starts and ends exactly at month start/end" do
      assert partial_time_labels(["2023-03-01"], %{
               dimensions: ["time:month"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-01 00:00:00Z], ~U[2023-03-31 23:59:59Z]),
               now: @now,
               timezone: "UTC"
             }) == []
    end

    test "first week bucket is partial if date range start is one second after actual week start" do
      # Week of 2023-03-06 (Mon) to 2023-03-12 (Sun)
      assert partial_time_labels(["2023-03-06"], %{
               dimensions: ["time:week"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-06 00:00:01Z], ~U[2023-03-12 23:59:59Z]),
               now: @now,
               timezone: "UTC"
             }) == ["2023-03-06"]
    end

    test "last week bucket is partial if date range end is one second before actual week end" do
      # Week of 2023-03-06 (Mon) to 2023-03-12 (Sun)
      assert partial_time_labels(["2023-03-06"], %{
               dimensions: ["time:week"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-06 00:00:00Z], ~U[2023-03-12 23:59:58Z]),
               now: @now,
               timezone: "UTC"
             }) == ["2023-03-06"]
    end

    test "a week bucket is not partial if date range starts and ends exactly at week start/end" do
      # Week of 2023-03-06 (Mon) to 2023-03-12 (Sun)
      assert partial_time_labels(["2023-03-06"], %{
               dimensions: ["time:week"],
               utc_time_range:
                 DateTimeRange.new!(~U[2023-03-06 00:00:00Z], ~U[2023-03-12 23:59:59Z]),
               now: @now,
               timezone: "UTC"
             }) == []
    end
  end

  describe "time_labels/1" do
    test "with time:month dimension" do
      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-17], ~D[2022-02-01], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-01",
               "2022-02-01"
             ]

      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-01], ~D[2022-03-07], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-01",
               "2022-02-01",
               "2022-03-01"
             ]
    end

    test "with time:week dimension" do
      assert time_labels(%{
               dimensions: ["time:week"],
               utc_time_range: DateTimeRange.new!(~D[2020-12-20], ~D[2021-01-08], "UTC"),
               timezone: "UTC"
             }) == [
               "2020-12-20",
               "2020-12-21",
               "2020-12-28",
               "2021-01-04"
             ]

      assert time_labels(%{
               dimensions: ["time:week"],
               utc_time_range: DateTimeRange.new!(~D[2020-12-21], ~D[2021-01-03], "UTC"),
               timezone: "UTC"
             }) == [
               "2020-12-21",
               "2020-12-28"
             ]
    end

    test "with time:day dimension" do
      assert time_labels(%{
               dimensions: ["time:day"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-17], ~D[2022-02-02], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-17",
               "2022-01-18",
               "2022-01-19",
               "2022-01-20",
               "2022-01-21",
               "2022-01-22",
               "2022-01-23",
               "2022-01-24",
               "2022-01-25",
               "2022-01-26",
               "2022-01-27",
               "2022-01-28",
               "2022-01-29",
               "2022-01-30",
               "2022-01-31",
               "2022-02-01",
               "2022-02-02"
             ]
    end

    test "with time:hour dimension" do
      assert time_labels(%{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-17], ~D[2022-01-17], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-17 00:00:00",
               "2022-01-17 01:00:00",
               "2022-01-17 02:00:00",
               "2022-01-17 03:00:00",
               "2022-01-17 04:00:00",
               "2022-01-17 05:00:00",
               "2022-01-17 06:00:00",
               "2022-01-17 07:00:00",
               "2022-01-17 08:00:00",
               "2022-01-17 09:00:00",
               "2022-01-17 10:00:00",
               "2022-01-17 11:00:00",
               "2022-01-17 12:00:00",
               "2022-01-17 13:00:00",
               "2022-01-17 14:00:00",
               "2022-01-17 15:00:00",
               "2022-01-17 16:00:00",
               "2022-01-17 17:00:00",
               "2022-01-17 18:00:00",
               "2022-01-17 19:00:00",
               "2022-01-17 20:00:00",
               "2022-01-17 21:00:00",
               "2022-01-17 22:00:00",
               "2022-01-17 23:00:00"
             ]

      assert time_labels(%{
               dimensions: ["time:hour"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-17], ~D[2022-01-18], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-17 00:00:00",
               "2022-01-17 01:00:00",
               "2022-01-17 02:00:00",
               "2022-01-17 03:00:00",
               "2022-01-17 04:00:00",
               "2022-01-17 05:00:00",
               "2022-01-17 06:00:00",
               "2022-01-17 07:00:00",
               "2022-01-17 08:00:00",
               "2022-01-17 09:00:00",
               "2022-01-17 10:00:00",
               "2022-01-17 11:00:00",
               "2022-01-17 12:00:00",
               "2022-01-17 13:00:00",
               "2022-01-17 14:00:00",
               "2022-01-17 15:00:00",
               "2022-01-17 16:00:00",
               "2022-01-17 17:00:00",
               "2022-01-17 18:00:00",
               "2022-01-17 19:00:00",
               "2022-01-17 20:00:00",
               "2022-01-17 21:00:00",
               "2022-01-17 22:00:00",
               "2022-01-17 23:00:00",
               "2022-01-18 00:00:00",
               "2022-01-18 01:00:00",
               "2022-01-18 02:00:00",
               "2022-01-18 03:00:00",
               "2022-01-18 04:00:00",
               "2022-01-18 05:00:00",
               "2022-01-18 06:00:00",
               "2022-01-18 07:00:00",
               "2022-01-18 08:00:00",
               "2022-01-18 09:00:00",
               "2022-01-18 10:00:00",
               "2022-01-18 11:00:00",
               "2022-01-18 12:00:00",
               "2022-01-18 13:00:00",
               "2022-01-18 14:00:00",
               "2022-01-18 15:00:00",
               "2022-01-18 16:00:00",
               "2022-01-18 17:00:00",
               "2022-01-18 18:00:00",
               "2022-01-18 19:00:00",
               "2022-01-18 20:00:00",
               "2022-01-18 21:00:00",
               "2022-01-18 22:00:00",
               "2022-01-18 23:00:00"
             ]
    end

    test "with a different time range" do
      {:ok, from_timestamp, _} = DateTime.from_iso8601("2024-09-04T21:53:17+03:00")
      {:ok, to_timestamp, _} = DateTime.from_iso8601("2024-09-05T05:59:59+03:00")

      assert time_labels(%{
               dimensions: ["time:hour"],
               utc_time_range:
                 DateTimeRange.new!(from_timestamp, to_timestamp)
                 |> DateTimeRange.to_timezone("Etc/UTC"),
               timezone: "Europe/Tallinn"
             }) == [
               "2024-09-04 21:00:00",
               "2024-09-04 22:00:00",
               "2024-09-04 23:00:00",
               "2024-09-05 00:00:00",
               "2024-09-05 01:00:00",
               "2024-09-05 02:00:00",
               "2024-09-05 03:00:00",
               "2024-09-05 04:00:00",
               "2024-09-05 05:00:00"
             ]
    end

    test "with time:minute dimension" do
      now = DateTime.new!(~D[2024-01-01], ~T[12:30:57], "UTC")

      # ~U[2024-01-01 12:00:57Z]
      first_dt = DateTime.shift(now, minute: -30)
      # ~U[2024-01-01 12:31:02Z]
      last_dt = DateTime.shift(now, second: 5)

      assert time_labels(%{
               dimensions: ["time:minute"],
               now: now,
               utc_time_range: DateTimeRange.new!(first_dt, last_dt),
               timezone: "UTC"
             }) == [
               "2024-01-01 12:00:00",
               "2024-01-01 12:01:00",
               "2024-01-01 12:02:00",
               "2024-01-01 12:03:00",
               "2024-01-01 12:04:00",
               "2024-01-01 12:05:00",
               "2024-01-01 12:06:00",
               "2024-01-01 12:07:00",
               "2024-01-01 12:08:00",
               "2024-01-01 12:09:00",
               "2024-01-01 12:10:00",
               "2024-01-01 12:11:00",
               "2024-01-01 12:12:00",
               "2024-01-01 12:13:00",
               "2024-01-01 12:14:00",
               "2024-01-01 12:15:00",
               "2024-01-01 12:16:00",
               "2024-01-01 12:17:00",
               "2024-01-01 12:18:00",
               "2024-01-01 12:19:00",
               "2024-01-01 12:20:00",
               "2024-01-01 12:21:00",
               "2024-01-01 12:22:00",
               "2024-01-01 12:23:00",
               "2024-01-01 12:24:00",
               "2024-01-01 12:25:00",
               "2024-01-01 12:26:00",
               "2024-01-01 12:27:00",
               "2024-01-01 12:28:00",
               "2024-01-01 12:29:00"
             ]
    end
  end
end
