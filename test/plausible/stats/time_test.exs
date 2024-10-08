defmodule Plausible.Stats.TimeTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Time
  alias Plausible.Stats.DateTimeRange

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
