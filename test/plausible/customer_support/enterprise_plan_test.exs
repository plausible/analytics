defmodule Plausible.CustomerSupport.EnterprisePlanTest do
  use Plausible
  use Plausible.DataCase, async: true
  @moduletag :ee_only

  on_ee do
    alias Plausible.CustomerSupport.EnterprisePlan

    describe "estimate/8" do
      test "calculates cost for business plan with monthly billing" do
        result =
          EnterprisePlan.estimate(
            :business,
            "monthly",
            20_000_000,
            1000,
            30,
            1_000,
            ["sites_api"]
          )

        assert result == Decimal.new("1088.00")
      end

      test "calculates cost for business plan with yearly billing" do
        result =
          EnterprisePlan.estimate(
            :business,
            "yearly",
            20_000_000,
            1000,
            30,
            1_000,
            ["sites_api"]
          )

        assert result == Decimal.new("10880.00")
      end
    end

    describe "pv_rate/2" do
      test "returns correct rate for growth plan" do
        assert EnterprisePlan.pv_rate(:growth, 20_000_000) == 319
        assert EnterprisePlan.pv_rate(:growth, 50_000_000) == 689
        assert EnterprisePlan.pv_rate(:growth, 100_000_000) == 1029
        assert EnterprisePlan.pv_rate(:growth, 200_000_000) == 1629
        assert EnterprisePlan.pv_rate(:growth, 300_000_000) == 2369
        assert EnterprisePlan.pv_rate(:growth, 400_000_000) == 2989
        assert EnterprisePlan.pv_rate(:growth, 500_000_000) == 3729
        assert EnterprisePlan.pv_rate(:growth, 1_000_000_000) == 7219
        assert EnterprisePlan.pv_rate(:growth, 1_500_000_000) == 7219
      end

      test "returns correct rate for business plan" do
        assert EnterprisePlan.pv_rate(:business, 20_000_000) == 639
        assert EnterprisePlan.pv_rate(:business, 50_000_000) == 1379
        assert EnterprisePlan.pv_rate(:business, 100_000_000) == 2059
        assert EnterprisePlan.pv_rate(:business, 200_000_000) == 3259
        assert EnterprisePlan.pv_rate(:business, 300_000_000) == 4739
        assert EnterprisePlan.pv_rate(:business, 400_000_000) == 5979
        assert EnterprisePlan.pv_rate(:business, 500_000_000) == 7459
        assert EnterprisePlan.pv_rate(:business, 1_000_000_000) == 14_439
        assert EnterprisePlan.pv_rate(:business, 1_500_000_000) == 14_439
      end
    end

    describe "sites_rate/1" do
      test "calculates rate based on number of sites" do
        assert EnterprisePlan.sites_rate(10) == 1.0
        assert EnterprisePlan.sites_rate(20) == 2.0
      end
    end

    describe "team_members_rate/1" do
      test "calculates rate based on number of team members" do
        assert EnterprisePlan.team_members_rate(5) == 25
        assert EnterprisePlan.team_members_rate(10) == 50
      end
    end

    describe "api_calls_rate/1" do
      test "returns correct rate for API calls" do
        assert EnterprisePlan.api_calls_rate(500) == 100
        assert EnterprisePlan.api_calls_rate(1_500) == 200
        assert EnterprisePlan.api_calls_rate(2_000) == 200
        assert EnterprisePlan.api_calls_rate(3_000) == 300
        assert EnterprisePlan.api_calls_rate(3_500) == 300
      end
    end

    describe "features_rate/1" do
      test "returns correct rate based on features" do
        assert EnterprisePlan.features_rate(["sites_api"]) == 99
        assert EnterprisePlan.features_rate([]) == 0
      end
    end
  end
end
