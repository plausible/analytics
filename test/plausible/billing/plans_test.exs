defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase, async: true
  alias Plausible.Billing.Plans

  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v4_plan_id "change-me-749342"

  describe "getting subscription plans for user" do
    test "growth_plans_for/1 shows v1 pricing for users who are already on v1 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert List.first(Plans.growth_plans_for(user)).monthly_product_id == @v1_plan_id
    end

    test "growth_plans_for/1 shows v2 pricing for users who are already on v2 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      assert List.first(Plans.growth_plans_for(user)).monthly_product_id == @v2_plan_id
    end

    test "growth_plans_for/1 shows v2 pricing for users who signed up in 2021" do
      user = insert(:user, inserted_at: ~N[2021-12-31 00:00:00])

      assert List.first(Plans.growth_plans_for(user)).monthly_product_id == @v2_plan_id
    end

    test "growth_plans_for/1 shows v4 pricing for everyone else" do
      user = insert(:user)

      assert List.first(Plans.growth_plans_for(user)).monthly_product_id == @v4_plan_id
    end

    test "growth_plans_for/1 does not return business plans" do
      user = insert(:user)

      Plans.growth_plans_for(user)
      |> Enum.each(fn plan ->
        assert plan.kind != :business
      end)
    end

    test "business_plans/0 returns only v4 business plans" do
      Plans.business_plans()
      |> Enum.each(fn plan ->
        assert plan.kind == :business
      end)
    end
  end

  describe "subscription_interval" do
    test "is based on the plan if user is on a standard plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert Plans.subscription_interval(user.subscription) == "monthly"
    end

    test "is N/A for free plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Plans.subscription_interval(user.subscription) == "N/A"
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan = insert(:enterprise_plan, user_id: user.id, billing_interval: :yearly)

      subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert Plans.subscription_interval(subscription) == :yearly
    end
  end

  describe "suggested_plan/2" do
    test "returns suggested plan based on usage" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 100_000,
               monthly_cost: nil,
               monthly_product_id: "558745",
               volume: "100k",
               yearly_cost: nil,
               yearly_product_id: "590752"
             } = Plans.suggest(user, 10_000)

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 200_000,
               monthly_cost: nil,
               monthly_product_id: "597485",
               volume: "200k",
               yearly_cost: nil,
               yearly_product_id: "597486"
             } = Plans.suggest(user, 100_000)
    end

    test "returns nil when user has enterprise-level usage" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      assert :enterprise == Plans.suggest(user, 100_000_000)
    end

    test "returns nil when user is on an enterprise plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      _enterprise_plan = insert(:enterprise_plan, user_id: user.id, billing_interval: :yearly)
      assert :enterprise == Plans.suggest(user, 10_000)
    end
  end

  describe "yearly_product_ids/0" do
    test "lists yearly plan ids" do
      assert [
               "572810",
               "590752",
               "597486",
               "597488",
               "597643",
               "597310",
               "597312",
               "642354",
               "642356",
               "650653",
               "648089",
               "653232",
               "653234",
               "653236",
               "653239",
               "653242",
               "653254",
               "653256",
               "653257",
               "653258",
               "653259",
               "749343",
               "749345",
               "749347",
               "749349",
               "749352",
               "749355",
               "749357",
               "749359",
               "change-me-749343",
               "change-me-749345",
               "change-me-749347",
               "change-me-749349",
               "change-me-749352",
               "change-me-749355",
               "change-me-749357",
               "change-me-749359",
               "change-me-749343",
               "change-me-749345",
               "change-me-749347",
               "change-me-749349",
               "change-me-749352",
               "change-me-749355",
               "change-me-749357",
               "change-me-749359"
             ] == Plans.yearly_product_ids()
    end
  end
end
