defmodule PlausibleWeb.StatsViewTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.StatsView
  doctest PlausibleWeb.StatsView

  describe "large_number_format" do
    test "numbers under 1000 stay the same" do
      assert StatsView.large_number_format(100) == "100"
    end

    test "1000 becomes 1k" do
      assert StatsView.large_number_format(1000) == "1k"
    end

    test "1111 becomes 1.1k" do
      assert StatsView.large_number_format(1111) == "1.1k"
    end

    test "10_000 becomes 10k" do
      assert StatsView.large_number_format(10_000) == "10k"
    end

    test "15_993 becomes 15.9k" do
      assert StatsView.large_number_format(15_923) == "15.9k"
    end

    test "wat" do
      assert StatsView.large_number_format(49012) == "49k"
    end

    test "999_999 becomes 999k" do
      assert StatsView.large_number_format(999_999) == "999k"
    end

    test "1_000_000 becomes 1m" do
      assert StatsView.large_number_format(1_000_000) == "1M"
    end

    test "2_590_000 becomes 2.5m" do
      assert StatsView.large_number_format(2_590_000) == "2.5M"
    end

    test "99_999_999 becomes 99.9m" do
      assert StatsView.large_number_format(99_999_999) == "99.9M"
    end

    test "101_000_000 becomes 101m" do
      assert StatsView.large_number_format(101_000_000) == "101M"
    end

    test "2_500_000_000 becomes 2.5bn" do
      assert StatsView.large_number_format(2_500_000_000) == "2.5B"
    end

    test "25_500_000_000 becomes 25bn" do
      assert StatsView.large_number_format(25_500_000_000) == "25.5B"
    end

    test "250_500_000_000 becomes 250bn" do
      assert StatsView.large_number_format(250_500_000_000) == "250B"
    end
  end
end
