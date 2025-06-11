defmodule Plausible.Billing.PlanBenefitsTest do
  use ExUnit.Case, async: true

  alias Plausible.Billing.{Plans, PlanBenefits}

  describe "for_starter/1" do
    test "returns v5 Starter plan benefits" do
      assert PlanBenefits.for_starter(get_10k_plan(5, :starter)) == [
               "One site",
               "3 years of data retention",
               "Intuitive, fast and privacy-friendly dashboard",
               "Email/Slack reports",
               "Google Analytics import",
               "Goals and custom events",
               "Saved Segments"
             ]
    end
  end

  describe "for_growth/2" do
    test "returns v5 Growth plan benefits" do
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))

      assert PlanBenefits.for_growth(get_10k_plan(5, :growth), starter_benefits) == [
               "Everything in Starter",
               "Up to 3 sites",
               "Up to 3 team members",
               "Team Management",
               "Shared Links",
               "Embedded Dashboards",
               "Shared Segments"
             ]
    end

    test "returns v4 Growth plan benefits" do
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))

      assert PlanBenefits.for_growth(get_10k_plan(4, :growth), starter_benefits) == [
               "Everything in Starter",
               "Up to 10 sites",
               "Up to 3 team members",
               "Team Management",
               "Shared Links",
               "Embedded Dashboards"
             ]
    end

    for generation <- [1, 2, 3] do
      test "returns v#{generation} Growth plan benefits (with empty Starter benefits)" do
        growth_plan = get_10k_plan(unquote(generation), :growth)

        assert PlanBenefits.for_growth(growth_plan, []) == [
                 "Up to 50 sites",
                 "Unlimited team members",
                 "Goals and custom events",
                 "Custom Properties",
                 "Stats API (600 requests per hour)",
                 "Looker Studio Connector"
               ]
      end
    end
  end

  describe "for_business/3" do
    test "returns v5 Business plan benefits (with Growth v5 plans available)" do
      business_plan = get_10k_plan(5, :business)
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))
      growth_benefits = PlanBenefits.for_growth(get_10k_plan(5, :growth), starter_benefits)

      assert PlanBenefits.for_business(business_plan, growth_benefits, starter_benefits) == [
               "Everything in Growth",
               "Up to 10 sites",
               "Up to 10 team members",
               "5 years of data retention",
               "Custom Properties",
               "Stats API (600 requests per hour)",
               "Looker Studio Connector",
               "Ecommerce revenue attribution",
               "Funnels"
             ]
    end

    test "returns v4 Business plan benefits (with Growth v4 plans available)" do
      business_plan = get_10k_plan(4, :business)
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))
      growth_benefits = PlanBenefits.for_growth(get_10k_plan(4, :growth), starter_benefits)

      assert PlanBenefits.for_business(business_plan, growth_benefits, starter_benefits) == [
               "Everything in Growth",
               "Up to 50 sites",
               "Up to 10 team members",
               "5 years of data retention",
               "Custom Properties",
               "Ecommerce revenue attribution",
               "Funnels",
               "Stats API (600 requests per hour)",
               "Looker Studio Connector",
               "Shared Segments"
             ]
    end

    for generation <- [1, 2, 3] do
      test "returns v3 Business plan benefits (with Growth v#{generation} plans available)" do
        business_plan = get_10k_plan(3, :business)

        starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))

        growth_benefits =
          PlanBenefits.for_growth(get_10k_plan(unquote(generation), :growth), starter_benefits)

        assert PlanBenefits.for_business(
                 business_plan,
                 growth_benefits,
                 starter_benefits
               ) == [
                 "Everything in Growth",
                 "Ecommerce revenue attribution",
                 "Funnels",
                 "Shared Segments"
               ]
      end
    end
  end

  describe "for_enterprise/1" do
    test "with v5 business benefits" do
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))
      growth_benefits = PlanBenefits.for_growth(get_10k_plan(5, :growth), starter_benefits)

      v5_business_benefits =
        PlanBenefits.for_business(get_10k_plan(5, :business), growth_benefits, starter_benefits)

      assert PlanBenefits.for_enterprise(v5_business_benefits) == [
               "Everything in Business",
               "10+ sites",
               "10+ team members",
               "600+ Stats API requests per hour",
               "Sites API",
               "5+ years of data retention",
               "Technical onboarding",
               "Priority support"
             ]
    end

    test "with v4 business benefits" do
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))
      growth_benefits = PlanBenefits.for_growth(get_10k_plan(4, :growth), starter_benefits)

      v4_business_benefits =
        PlanBenefits.for_business(get_10k_plan(4, :business), growth_benefits, starter_benefits)

      assert PlanBenefits.for_enterprise(v4_business_benefits) == [
               "Everything in Business",
               "50+ sites",
               "10+ team members",
               "600+ Stats API requests per hour",
               "Sites API",
               "5+ years of data retention",
               "Technical onboarding",
               "Priority support"
             ]
    end

    test "with v3 business benefits" do
      starter_benefits = PlanBenefits.for_starter(get_10k_plan(5, :starter))
      growth_benefits = PlanBenefits.for_growth(get_10k_plan(3, :growth), starter_benefits)

      v3_business_benefits =
        PlanBenefits.for_business(get_10k_plan(3, :business), growth_benefits, starter_benefits)

      assert PlanBenefits.for_enterprise(v3_business_benefits) == [
               "Everything in Business",
               "50+ sites",
               "600+ Stats API requests per hour",
               "Sites API",
               "Technical onboarding",
               "Priority support"
             ]
    end
  end

  defp get_10k_plan(generation, kind) do
    Enum.find(Plans.all(), fn plan ->
      plan.generation == generation and plan.kind == kind and
        plan.monthly_pageview_limit == 10_000
    end)
  end
end
