defmodule Plausible.Stats.TimeTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Time
  alias Plausible.Stats.DateTimeRange
  alias Plausible.Stats.Query

  describe "time_labels/1" do
    test "with time:month dimension" do
      assert time_labels(%Query{
               dimensions: ["visit:device", "time:month"],
               utc_time_range: DateTimeRange.new!(~D[2022-01-17], ~D[2022-02-01], "UTC"),
               timezone: "UTC"
             }) == [
               "2022-01-01",
               "2022-02-01"
             ]

      assert time_labels(%Query{
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
      assert time_labels(%Query{
               dimensions: ["time:week"],
               utc_time_range: DateTimeRange.new!(~D[2020-12-20], ~D[2021-01-08], "UTC"),
               timezone: "UTC"
             }) == [
               "2020-12-20",
               "2020-12-21",
               "2020-12-28",
               "2021-01-04"
             ]

      assert time_labels(%Query{
               dimensions: ["time:week"],
               utc_time_range: DateTimeRange.new!(~D[2020-12-21], ~D[2021-01-03], "UTC"),
               timezone: "UTC"
             }) == [
               "2020-12-21",
               "2020-12-28"
             ]
    end

    test "with time:day dimension" do
      assert time_labels(%Query{
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
      assert time_labels(%Query{
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

      assert time_labels(%Query{
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

      assert time_labels(%Query{
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

      assert time_labels(%Query{
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

  describe "time_labels/1 with current period trimming" do
    test "trims future dates for current month period" do
      now = DateTime.new!(~D[2024-01-15], ~T[12:00:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:day"],
               period: "month",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2024-01-01], ~D[2024-01-31], "UTC"),
               timezone: "UTC"
             }) == [
               "2024-01-01",
               "2024-01-02",
               "2024-01-03",
               "2024-01-04",
               "2024-01-05",
               "2024-01-06",
               "2024-01-07",
               "2024-01-08",
               "2024-01-09",
               "2024-01-10",
               "2024-01-11",
               "2024-01-12",
               "2024-01-13",
               "2024-01-14",
               "2024-01-15"
             ]
    end

    test "trims future dates for current month period for a given timezone" do
      now = DateTime.new!(~D[2024-01-15], ~T[12:00:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:day"],
               period: "month",
               now: now,
               utc_time_range:
                 DateTimeRange.new!(~D[2024-01-01], ~D[2024-01-31], "Pacific/Fiji")
                 |> DateTimeRange.to_timezone("Etc/UTC"),
               timezone: "Pacific/Fiji"
             }) == [
               "2024-01-01",
               "2024-01-02",
               "2024-01-03",
               "2024-01-04",
               "2024-01-05",
               "2024-01-06",
               "2024-01-07",
               "2024-01-08",
               "2024-01-09",
               "2024-01-10",
               "2024-01-11",
               "2024-01-12",
               "2024-01-13",
               "2024-01-14",
               "2024-01-15",
               "2024-01-16"
             ]
    end

    test "trims future dates for current year period" do
      now = DateTime.new!(~D[2024-03-15], ~T[12:00:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:month"],
               period: "year",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2024-01-01], ~D[2024-12-31], "UTC"),
               timezone: "UTC"
             }) == [
               "2024-01-01",
               "2024-02-01",
               "2024-03-01"
             ]
    end

    test "does not trim for historical periods" do
      now = DateTime.new!(~D[2024-01-15], ~T[12:00:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:day"],
               period: "month",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2023-06-01], ~D[2023-06-30], "UTC"),
               timezone: "UTC"
             }) == [
               "2023-06-01",
               "2023-06-02",
               "2023-06-03",
               "2023-06-04",
               "2023-06-05",
               "2023-06-06",
               "2023-06-07",
               "2023-06-08",
               "2023-06-09",
               "2023-06-10",
               "2023-06-11",
               "2023-06-12",
               "2023-06-13",
               "2023-06-14",
               "2023-06-15",
               "2023-06-16",
               "2023-06-17",
               "2023-06-18",
               "2023-06-19",
               "2023-06-20",
               "2023-06-21",
               "2023-06-22",
               "2023-06-23",
               "2023-06-24",
               "2023-06-25",
               "2023-06-26",
               "2023-06-27",
               "2023-06-28",
               "2023-06-29",
               "2023-06-30"
             ]
    end

    test "trims future weeks for current week period" do
      now = DateTime.new!(~D[2025-01-02], ~T[12:00:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:week"],
               period: "week",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2024-12-30], ~D[2025-01-12], "UTC"),
               timezone: "UTC"
             }) == [
               "2024-12-30",
               "2025-01-06"
             ]
    end

    test "trims future hours for current day period" do
      now = DateTime.new!(~D[2024-01-15], ~T[14:30:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:hour"],
               period: "day",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2024-01-15], ~D[2024-01-15], "UTC"),
               timezone: "UTC"
             }) == [
               "2024-01-15 00:00:00",
               "2024-01-15 01:00:00",
               "2024-01-15 02:00:00",
               "2024-01-15 03:00:00",
               "2024-01-15 04:00:00",
               "2024-01-15 05:00:00",
               "2024-01-15 06:00:00",
               "2024-01-15 07:00:00",
               "2024-01-15 08:00:00",
               "2024-01-15 09:00:00",
               "2024-01-15 10:00:00",
               "2024-01-15 11:00:00",
               "2024-01-15 12:00:00",
               "2024-01-15 13:00:00",
               "2024-01-15 14:00:00"
             ]
    end

    test "does not trim hours for historical day periods" do
      now = DateTime.new!(~D[2024-01-15], ~T[14:30:00], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:hour"],
               period: "day",
               now: now,
               utc_time_range: DateTimeRange.new!(~D[2024-01-10], ~D[2024-01-10], "UTC"),
               timezone: "UTC"
             }) == [
               "2024-01-10 00:00:00",
               "2024-01-10 01:00:00",
               "2024-01-10 02:00:00",
               "2024-01-10 03:00:00",
               "2024-01-10 04:00:00",
               "2024-01-10 05:00:00",
               "2024-01-10 06:00:00",
               "2024-01-10 07:00:00",
               "2024-01-10 08:00:00",
               "2024-01-10 09:00:00",
               "2024-01-10 10:00:00",
               "2024-01-10 11:00:00",
               "2024-01-10 12:00:00",
               "2024-01-10 13:00:00",
               "2024-01-10 14:00:00",
               "2024-01-10 15:00:00",
               "2024-01-10 16:00:00",
               "2024-01-10 17:00:00",
               "2024-01-10 18:00:00",
               "2024-01-10 19:00:00",
               "2024-01-10 20:00:00",
               "2024-01-10 21:00:00",
               "2024-01-10 22:00:00",
               "2024-01-10 23:00:00"
             ]
    end

    test "trims future hours for given timezone" do
      now = DateTime.new!(~D[2025-08-26], ~T[04:02:49], "UTC")

      assert time_labels(%Query{
               dimensions: ["time:hour"],
               period: "day",
               now: now,
               utc_time_range:
                 DateTimeRange.new!(~D[2025-08-26], ~D[2025-08-26], "Europe/Warsaw")
                 |> DateTimeRange.to_timezone("Etc/UTC"),
               timezone: "Europe/Warsaw"
             }) == [
               "2025-08-26 00:00:00",
               "2025-08-26 01:00:00",
               "2025-08-26 02:00:00",
               "2025-08-26 03:00:00",
               "2025-08-26 04:00:00",
               "2025-08-26 05:00:00",
               "2025-08-26 06:00:00"
             ]
    end
  end
end
