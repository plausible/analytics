defmodule PlausibleWeb.TextHelpersTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.TextHelpers
  doctest PlausibleWeb.TextHelpers

  describe "humanize_last_used_with_5_minute_precision/2" do
    for {shift, expected} <- [
          {[second: 0], "Less than 5 minutes ago"},
          {[minute: -4, second: -59], "Less than 5 minutes ago"},
          {[minute: -5], "Less than 10 minutes ago"},
          {[minute: -9, second: -59], "Less than 10 minutes ago"},
          {[minute: -10], "About 10 minutes ago"},
          {[minute: -14, second: -59], "About 10 minutes ago"},
          {[minute: -15], "About 15 minutes ago"},
          {[minute: -59, second: -59], "About 55 minutes ago"},
          {[minute: -60], "About 1 hour ago"},
          {[minute: -92, second: -29], "About 1 hour ago"},
          {[minute: -92, second: -30], "About 2 hours ago"},
          {[hour: -5], "About 5 hours ago"},
          {[hour: -23, minute: -59], "About 24 hours ago"},
          {[hour: -24], "1 day ago"},
          {[hour: -36, minute: -2, second: -29], "1 day ago"},
          {[hour: -36, minute: -2, second: -30], "2 days ago"},
          {[hour: -48], "2 days ago"},
          {[hour: -60, minute: -2, second: -29], "2 days ago"},
          {[hour: -60, minute: -2, second: -30], "3 days ago"},
          {[day: -10], "10 days ago"}
        ] do
      test "#{inspect(shift)} is #{inspect(expected)}" do
        now = NaiveDateTime.utc_now(:second)
        last_used_at = NaiveDateTime.shift(now, unquote(shift))

        assert TextHelpers.humanize_last_used_with_5_minute_precision(last_used_at, now) ==
                 unquote(expected)
      end
    end

    test "returns never when not used yet" do
      assert TextHelpers.humanize_last_used_with_5_minute_precision(nil) == "Never"
    end
  end

  describe "humanize_last_used_with_hourly_precision/2" do
    for {shift, expected} <- [
          {[second: 0], "Less than an hour ago"},
          {[minute: -59, second: -59], "Less than an hour ago"},
          {[minute: -60], "Less than 2 hours ago"},
          {[hour: -1, minute: -59, second: -59], "Less than 2 hours ago"},
          {[hour: -2], "About 2 hours ago"},
          {[hour: -2, minute: -59, second: -59], "About 2 hours ago"},
          {[hour: -3], "About 3 hours ago"},
          {[hour: -23, minute: -59], "About 23 hours ago"},
          {[hour: -24], "1 day ago"},
          {[hour: -36, minute: -29, second: -59], "1 day ago"},
          {[hour: -36, minute: -30], "2 days ago"},
          {[hour: -48], "2 days ago"},
          {[day: -10], "10 days ago"}
        ] do
      test "#{inspect(shift)} is #{inspect(expected)}" do
        now = NaiveDateTime.utc_now(:second)
        last_used_at = NaiveDateTime.shift(now, unquote(shift))

        assert TextHelpers.humanize_last_used_with_hourly_precision(last_used_at, now) ==
                 unquote(expected)
      end
    end

    test "returns never when not used yet" do
      assert TextHelpers.humanize_last_used_with_hourly_precision(nil) == "Never"
    end
  end

  describe "number_format" do
    test "numbers under 1000 stay the same" do
      assert TextHelpers.number_format(0) == "0"
      assert TextHelpers.number_format(1) == "1"
      assert TextHelpers.number_format(123) == "123"
      assert TextHelpers.number_format(999) == "999"
    end

    test "thousands get comma separator" do
      assert TextHelpers.number_format(1_000) == "1,000"
      assert TextHelpers.number_format(1_234) == "1,234"
      assert TextHelpers.number_format(12_345) == "12,345"
      assert TextHelpers.number_format(123_456) == "123,456"
    end

    test "millions get multiple comma separators" do
      assert TextHelpers.number_format(1_000_000) == "1,000,000"
      assert TextHelpers.number_format(1_234_567) == "1,234,567"
      assert TextHelpers.number_format(12_345_678) == "12,345,678"
      assert TextHelpers.number_format(123_456_789) == "123,456,789"
    end

    test "billions get multiple comma separators" do
      assert TextHelpers.number_format(1_000_000_000) == "1,000,000,000"
      assert TextHelpers.number_format(1_234_567_890) == "1,234,567,890"
      assert TextHelpers.number_format(12_345_678_901) == "12,345,678,901"
    end

    test "handles negative numbers" do
      assert TextHelpers.number_format(-1234) == "-1,234"
      assert TextHelpers.number_format(-1_234_567) == "-1,234,567"
    end

    test "handles edge cases" do
      assert TextHelpers.number_format(0) == "0"
      assert TextHelpers.number_format(-0) == "0"
    end
  end
end
