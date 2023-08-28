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

  test "site_usage/1 returns the amount of sites the user owns" do
    user = insert(:user)
    insert_list(3, :site, memberships: [build(:site_membership, user: user, role: :owner)])
    insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])
    insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

    assert Quota.site_usage(user) == 3
  end

  describe "within_limit?/2" do
    test "returns true when quota is not exceeded" do
      assert Quota.within_limit?(3, 5)
    end

    test "returns true when limit is :unlimited" do
      assert Quota.within_limit?(10_000, :unlimited)
    end

    test "returns false when usage is at limit" do
      refute Quota.within_limit?(3, 3)
    end

    test "returns false when usage exceeds the limit" do
      refute Quota.within_limit?(10, 3)
    end
  end

  describe "monthly_pageview_limit/1" do
    test "is based on the plan if user is on a standard plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert Quota.monthly_pageview_limit(user.subscription) == 10_000
    end

    test "free_10k has 10k monthly_pageview_limit" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Quota.monthly_pageview_limit(user.subscription) == 10_000
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan =
        insert(:enterprise_plan, user_id: user.id, monthly_pageview_limit: 100_000)

      subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert Quota.monthly_pageview_limit(subscription) == 100_000
    end

    test "does not limit pageviews when user has a pending enterprise plan" do
      user = insert(:user)
      subscription = insert(:subscription, user_id: user.id, paddle_plan_id: "pending-enterprise")

      assert Quota.monthly_pageview_limit(subscription) == :unlimited
    end
  end

  describe "monthly_pageview_usage/1" do
    test "is 0 with no events" do
      user = insert(:user)

      assert Quota.monthly_pageview_usage(user) == 0
    end

    test "counts the total number of events from all sites the user owns" do
      user = insert(:user)
      site1 = insert(:site, members: [user])
      site2 = insert(:site, members: [user])

      populate_stats(site1, [
        build(:pageview),
        build(:pageview)
      ])

      populate_stats(site2, [
        build(:pageview),
        build(:event, name: "custom events")
      ])

      assert Quota.monthly_pageview_usage(user) == 4
    end

    test "only counts usage from sites where the user is the owner" do
      user = insert(:user)

      insert(:site,
        domain: "site-with-no-views.com",
        memberships: [
          build(:site_membership, user: user, role: :owner)
        ]
      )

      insert(:site,
        domain: "test-site.com",
        memberships: [
          build(:site_membership, user: user, role: :admin)
        ]
      )

      assert Quota.monthly_pageview_usage(user) == 0
    end
  end
end
