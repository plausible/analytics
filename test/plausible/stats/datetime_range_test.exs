defmodule Plausible.Stats.DateTimeRangeTest do
  use Plausible.DataCase, async: true

  alias Plausible.Stats.DateTimeRange

  describe "new!/2" do
    test "creates a range when datetimes are in correct order" do
      first = DateTime.new!(~D[2023-01-01], ~T[10:00:00], "UTC")
      last = DateTime.new!(~D[2023-01-02], ~T[10:00:00], "UTC")

      range = DateTimeRange.new!(first, last)

      assert range.first == first
      assert range.last == last
    end

    test "swaps datetimes when in reverse order" do
      first = DateTime.new!(~D[2023-02-01], ~T[10:00:00], "UTC")
      last = DateTime.new!(~D[2023-01-01], ~T[10:00:00], "UTC")

      range = DateTimeRange.new!(first, last)

      assert range.first == last
      assert range.last == first
    end

    test "truncates microseconds" do
      first = DateTime.new!(~D[2023-01-01], ~T[10:00:00.123], "UTC")
      last = DateTime.new!(~D[2023-01-02], ~T[10:00:00.456], "UTC")

      range = DateTimeRange.new!(first, last)

      assert range.first == DateTime.truncate(first, :second)
      assert range.last == DateTime.truncate(last, :second)
    end
  end

  describe "new!/3 with dates and timezone" do
    test "creates range with start and end of day" do
      first_date = ~D[2023-01-01]
      last_date = ~D[2023-01-02]

      range = DateTimeRange.new!(first_date, last_date, "UTC")

      assert range.first == DateTime.new!(first_date, ~T[00:00:00], "UTC")
      assert range.last == DateTime.new!(last_date, ~T[23:59:59], "UTC")
    end

    test "handles timezone gaps (spring forward)" do
      # https://stackoverflow.com/questions/18489927/a-day-without-midnight
      range = DateTimeRange.new!(~D[2020-03-29], ~D[2020-03-29], "Asia/Beirut")

      assert range.first == DateTime.new!(~D[2020-03-29], ~T[01:00:00], "Asia/Beirut")
      assert range.last == DateTime.new!(~D[2020-03-29], ~T[23:59:59], "Asia/Beirut")
    end
  end

  describe "to_timezone/2" do
    test "converts range to specified timezone" do
      first = DateTime.new!(~D[2023-01-01], ~T[10:00:00], "UTC")
      last = DateTime.new!(~D[2023-01-02], ~T[10:00:00], "UTC")
      range = DateTimeRange.new!(first, last)

      converted = DateTimeRange.to_timezone(range, "America/New_York")

      assert converted.first == DateTime.shift_zone!(first, "America/New_York")
      assert converted.last == DateTime.shift_zone!(last, "America/New_York")
    end
  end

  describe "to_date_range/2" do
    test "converts datetime range to date range" do
      first = DateTime.new!(~D[2023-01-01], ~T[10:00:00], "UTC")
      last = DateTime.new!(~D[2023-01-05], ~T[10:00:00], "UTC")
      range = DateTimeRange.new!(first, last)

      date_range = DateTimeRange.to_date_range(range, "UTC")

      assert date_range.first == ~D[2023-01-01]
      assert date_range.last == ~D[2023-01-05]
    end

    test "handles timezone conversions that cross date boundaries" do
      first = DateTime.new!(~D[2023-01-01], ~T[23:00:00], "UTC")
      last = DateTime.new!(~D[2023-01-02], ~T[04:59:59], "UTC")
      range = DateTimeRange.new!(first, last)

      date_range = DateTimeRange.to_date_range(range, "America/New_York")

      assert date_range.first == ~D[2023-01-01]
      assert date_range.last == ~D[2023-01-01]
    end
  end
end
