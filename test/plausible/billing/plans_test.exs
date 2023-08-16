defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase, async: true
  alias Plausible.Billing.Plans

  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_plan_id "749342"

  describe "for_user" do
    test "shows v1 pricing for users who are already on v1 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert List.first(Plans.for_user(user)).monthly_product_id == @v1_plan_id
    end

    test "shows v2 pricing for users who are already on v2 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      assert List.first(Plans.for_user(user)).monthly_product_id == @v2_plan_id
    end

    test "shows v2 pricing for users who signed up in 2021" do
      user = insert(:user, inserted_at: ~N[2021-12-31 00:00:00])

      assert List.first(Plans.for_user(user)).monthly_product_id == @v2_plan_id
    end

    test "shows v3 pricing for everyone else" do
      user = insert(:user)

      assert List.first(Plans.for_user(user)).monthly_product_id == @v3_plan_id
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

  describe "suggested_plan/2" do
    test "returns suggested plan based on usage" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 100_000,
               monthly_cost: "$12",
               monthly_product_id: "558745",
               volume: "100k",
               yearly_cost: "$96",
               yearly_product_id: "590752"
             } = Plans.suggest(user, 10_000)

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 200_000,
               monthly_cost: "$18",
               monthly_product_id: "597485",
               volume: "200k",
               yearly_cost: "$144",
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
               "749359"
             ] == Plans.yearly_product_ids()
    end
  end

  describe "site_limit/1" do
    test "returns 50 when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert 50 == Plans.site_limit(user_on_v1)
      assert 50 == Plans.site_limit(user_on_v2)
      assert 50 == Plans.site_limit(user_on_v3)
    end

    test "returns 50 when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert 50 == Plans.site_limit(user)
    end

    test "returns unlimited when user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan =
        insert(:enterprise_plan,
          user_id: user.id,
          monthly_pageview_limit: 100_000,
          site_limit: 500
        )

      _subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert :unlimited == Plans.site_limit(user)
    end

    test "returns 50 when user in on trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: 7))
      assert 50 == Plans.site_limit(user)

      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: -7))
      assert 50 == Plans.site_limit(user)
    end

    test "returns the subscription limit for enterprise users who have not paid yet" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: @v1_plan_id)
        )

      assert 50 == Plans.site_limit(user)
    end

    test "returns 50 for enterprise users who have not upgraded yet and are on trial" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: nil
        )

      assert 50 == Plans.site_limit(user)
    end

    test "is unlimited for enterprise customers" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: "123321")
        )

      assert :unlimited == Plans.site_limit(user)
    end

    test "is unlimited for enterprise customers who are due to change a plan" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "old-paddle-plan-id"),
          subscription: build(:subscription, paddle_plan_id: "old-paddle-plan-id")
        )

      insert(:enterprise_plan, user_id: user.id, paddle_plan_id: "new-paddle-plan-id")
      assert :unlimited == Plans.site_limit(user)
    end
  end
end
