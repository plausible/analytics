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
            "monthly",
            20_000_000,
            1000,
            30,
            1_000,
            ["sites_api"]
          )

        assert result == Decimal.new("1038.00")
      end

      test "calculates cost for business plan with monthly billing, SSO enabled and extra members" do
        result =
          EnterprisePlan.estimate(
            "monthly",
            20_000_000,
            1000,
            30,
            1_000,
            ["sites_api", "sso"]
          )

        assert result == Decimal.new("1537.00")
      end

      test "bugfix - from float" do
        result =
          EnterprisePlan.estimate(
            "monthly",
            20_000_000,
            0,
            0,
            0,
            ["sites_api"]
          )

        assert result == Decimal.new("738.00")
      end

      test "Bogdan's example (https://3.basecamp.com/5308029/buckets/26383192/card_tables/cards/8506177450#__recording_8689686259)" do
        result =
          EnterprisePlan.estimate(
            "monthly",
            10_000,
            500,
            15,
            600,
            []
          )

        assert result == Decimal.new("94.00")
      end

      test "calculates cost for business plan with yearly billing" do
        result =
          EnterprisePlan.estimate(
            "yearly",
            20_000_000,
            1000,
            30,
            1_000,
            ["sites_api"]
          )

        assert result == Decimal.new("10380.00")
      end
    end

    describe "pv_rate/2" do
      test "returns correct rate for business plan" do
        assert EnterprisePlan.pv_rate(10_000) == 19
        assert EnterprisePlan.pv_rate(100_000) == 39
        assert EnterprisePlan.pv_rate(200_000) == 59
        assert EnterprisePlan.pv_rate(500_000) == 99
        assert EnterprisePlan.pv_rate(1_000_000) == 139
        assert EnterprisePlan.pv_rate(2_000_000) == 179
        assert EnterprisePlan.pv_rate(5_000_000) == 259
        assert EnterprisePlan.pv_rate(10_000_000) == 339
        assert EnterprisePlan.pv_rate(20_000_000) == 639
        assert EnterprisePlan.pv_rate(50_000_000) == 1379
        assert EnterprisePlan.pv_rate(100_000_000) == 2059
        assert EnterprisePlan.pv_rate(200_000_000) == 3259
        assert EnterprisePlan.pv_rate(300_000_000) == 4739
        assert EnterprisePlan.pv_rate(400_000_000) == 5979
        assert EnterprisePlan.pv_rate(500_000_000) == 7459
        assert EnterprisePlan.pv_rate(1_000_000_000) == 14_439
        assert EnterprisePlan.pv_rate(1_500_000_000) == 14_439
      end
    end

    describe "sites_rate/1" do
      test "calculates rate based on number of sites" do
        assert EnterprisePlan.sites_rate(10) == 0
        assert EnterprisePlan.sites_rate(45) == 0
        assert EnterprisePlan.sites_rate(50) == 0
        assert EnterprisePlan.sites_rate(60) == 6.0
      end
    end

    describe "team_members_rate/1" do
      test "calculates rate based on number of team members" do
        assert EnterprisePlan.team_members_rate(5, 5) == 0
        assert EnterprisePlan.team_members_rate(10, 5) == 0
        assert EnterprisePlan.team_members_rate(15, 5) == 25
        assert EnterprisePlan.team_members_rate(20, 5) == 50
      end
    end

    describe "api_calls_rate/1" do
      test "returns correct rate for API calls" do
        assert EnterprisePlan.api_calls_rate(500) == 0
        assert EnterprisePlan.api_calls_rate(600) == 0
        assert EnterprisePlan.api_calls_rate(700) == 100
        assert EnterprisePlan.api_calls_rate(1_500) == 200
        assert EnterprisePlan.api_calls_rate(2_000) == 200
        assert EnterprisePlan.api_calls_rate(3_000) == 300
        assert EnterprisePlan.api_calls_rate(3_400) == 300
        assert EnterprisePlan.api_calls_rate(3_700) == 400
      end
    end

    describe "features_rate/1" do
      test "returns correct rate based on features" do
        assert EnterprisePlan.features_rate(["sites_api"]) == 99
        assert EnterprisePlan.features_rate(["sso"]) == 299
        assert EnterprisePlan.features_rate(["sso", "sites_api"]) == 398
        assert EnterprisePlan.features_rate(["funnels"]) == 0
        assert EnterprisePlan.features_rate([]) == 0
      end
    end
  end
end
