defmodule PlausibleWeb.TextHelpersTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.TextHelpers
  doctest PlausibleWeb.TextHelpers

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
