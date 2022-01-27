defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase
  alias Plausible.Billing.Plans

  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_plan_id "749342"

  describe "plans_for" do
    test "shows v1 pricing for users who are already on v1 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v1_plan_id
    end

    test "shows v2 pricing for users who are already on v2 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v2_plan_id
    end

    test "shows v2 pricing for users who signed up in 2021" do
      user = insert(:user, inserted_at: ~N[2021-12-31 00:00:00]) |> Repo.preload(:subscription)

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v2_plan_id
    end

    test "shows v3 pricing for everyone else" do
      user = insert(:user) |> Repo.preload(:subscription)

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v3_plan_id
    end
  end

  describe "allowance" do
    test "is based on the plan if user is on a standard plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert Plans.allowance(user.subscription) == 10_000
    end

    test "free_10k has 10k allowance" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Plans.allowance(user.subscription) == 10_000
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan =
        insert(:enterprise_plan, user_id: user.id, monthly_pageview_limit: 100_000)

      subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert Plans.allowance(subscription) == 100_000
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
end
