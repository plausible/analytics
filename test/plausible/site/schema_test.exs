defmodule Plausible.SiteTest do
  use Plausible.DataCase
  alias Plausible.Site

  doctest Plausible.Site

  describe "tz_offset/2" do
    test "returns offset from utc in seconds" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-01-01 00:00:00Z]) == -18_000
    end

    test "returns correct offset from utc during summer time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-07-01 00:00:00Z]) == -14_400
    end

    test "returns correct offset when changing from winter to summer time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-03-12 06:59:59Z]) == -18_000
      assert Site.tz_offset(site, ~U[2023-03-12 07:00:00Z]) == -14_400
    end

    test "returns correct offset when changing from summer to winter time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-11-05 05:59:59Z]) == -14_400
      assert Site.tz_offset(site, ~U[2023-11-05 06:00:00Z]) == -18_000
    end
  end
end
