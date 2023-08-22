defmodule Plausible.Billing.QuotaTest do
  use Plausible.DataCase, async: true
  alias Plausible.Billing.Quota

  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_plan_id "749342"

  describe "site_limit/1" do
    test "returns 50 when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert 50 == Quota.site_limit(user_on_v1)
      assert 50 == Quota.site_limit(user_on_v2)
      assert 50 == Quota.site_limit(user_on_v3)
    end

    test "returns 50 when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert 50 == Quota.site_limit(user)
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

      assert :unlimited == Quota.site_limit(user)
    end

    test "returns 50 when user in on trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: 7))
      assert 50 == Quota.site_limit(user)

      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: -7))
      assert 50 == Quota.site_limit(user)
    end

    test "returns the subscription limit for enterprise users who have not paid yet" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: @v1_plan_id)
        )

      assert 50 == Quota.site_limit(user)
    end

    test "returns 50 for enterprise users who have not upgraded yet and are on trial" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: nil
        )

      assert 50 == Quota.site_limit(user)
    end

    test "is unlimited for enterprise customers" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: "123321")
        )

      assert :unlimited == Quota.site_limit(user)
    end

    test "is unlimited for enterprise customers who are due to change a plan" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "old-paddle-plan-id"),
          subscription: build(:subscription, paddle_plan_id: "old-paddle-plan-id")
        )

      insert(:enterprise_plan, user_id: user.id, paddle_plan_id: "new-paddle-plan-id")
      assert :unlimited == Quota.site_limit(user)
    end
  end
end
