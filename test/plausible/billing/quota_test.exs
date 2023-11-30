defmodule Plausible.Billing.QuotaTest do
  use Plausible.DataCase, async: true
  use Plausible
  alias Plausible.Billing.{Quota, Plans}
  alias Plausible.Billing.Feature.{Goals, Props, StatsAPI}

  on_full_build do
    alias Plausible.Billing.Feature.Funnels
    alias Plausible.Billing.Feature.RevenueGoals
  end

  @legacy_plan_id "558746"
  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_plan_id "749342"
  @v3_business_plan_id "857481"
  @v4_1m_plan_id "857101"

  describe "site_limit/1" do
    @describetag :full_build_only
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

    test "returns 10 when user in on trial" do
      user =
        insert(:user,
          trial_expiry_date: Timex.shift(Timex.now(), days: 7)
        )

      assert 10 == Quota.site_limit(user)
    end

    test "returns 50 when user in on trial but registered before the business tier was live" do
      user =
        insert(:user,
          trial_expiry_date: Timex.shift(Timex.now(), days: 7),
          inserted_at: ~U[2023-10-01T00:00:00Z]
        )

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

    test "returns 10 for enterprise users who have not upgraded yet and are on trial" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: nil
        )

      assert 10 == Quota.site_limit(user)
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

  describe "below_limit?/2" do
    test "returns true when quota is not exceeded" do
      assert Quota.below_limit?(3, 5)
    end

    test "returns true when limit is :unlimited" do
      assert Quota.below_limit?(10_000, :unlimited)
    end

    test "returns false when usage is at limit" do
      refute Quota.below_limit?(3, 3)
    end

    test "returns false when usage exceeds the limit" do
      refute Quota.below_limit?(10, 3)
    end
  end

  describe "ensure_can_subscribe_to_plan/2" do
    test "returns :ok when site and team member limits are reached but not exceeded" do
      user = insert(:user)

      usage = %{
        monthly_pageviews: %{last_30_days: %{total: 1}},
        team_members: 3,
        sites: 10
      }

      plan = Plans.find(@v4_1m_plan_id)

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage) == :ok
    end

    test "returns all exceeded limits" do
      user = insert(:user)

      usage = %{
        monthly_pageviews: %{last_30_days: %{total: 1_150_001}},
        team_members: 4,
        sites: 11
      }

      plan = Plans.find(@v4_1m_plan_id)

      {:error, %{exceeded_limits: exceeded_limits}} =
        Quota.ensure_can_subscribe_to_plan(user, plan, usage)

      assert :monthly_pageview_limit in exceeded_limits
      assert :team_member_limit in exceeded_limits
      assert :site_limit in exceeded_limits
    end

    test "by the last 30 days usage, pageview limit for 10k plan is only exceeded when 30% over the limit" do
      user = insert(:user)

      usage_within_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 13_000}},
        team_members: 1,
        sites: 1
      }

      usage_over_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 13_001}},
        team_members: 1,
        sites: 1
      }

      plan = Plans.find(@v3_plan_id)

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_within_pageview_limit) == :ok

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_over_pageview_limit) ==
               {:error, %{exceeded_limits: [:monthly_pageview_limit]}}
    end

    test "by the last 30 days usage, pageview limit for all plans above 10k is exceeded when 15% over the limit" do
      user = insert(:user)

      usage_within_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 1_150_000}},
        team_members: 1,
        sites: 1
      }

      usage_over_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 1_150_001}},
        team_members: 1,
        sites: 1
      }

      plan = Plans.find(@v4_1m_plan_id)

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_within_pageview_limit) == :ok

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_over_pageview_limit) ==
               {:error, %{exceeded_limits: [:monthly_pageview_limit]}}
    end

    test "by billing cycles usage, pageview limit is exceeded when last two billing cycles exceed by 10%" do
      user = insert(:user)

      usage_within_pageview_limit = %{
        monthly_pageviews: %{penultimate_cycle: %{total: 11_000}, last_cycle: %{total: 10_999}},
        team_members: 1,
        sites: 1
      }

      usage_over_pageview_limit = %{
        monthly_pageviews: %{penultimate_cycle: %{total: 11_000}, last_cycle: %{total: 11_000}},
        team_members: 1,
        sites: 1
      }

      plan = Plans.find(@v3_plan_id)

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_within_pageview_limit) == :ok

      assert Quota.ensure_can_subscribe_to_plan(user, plan, usage_over_pageview_limit) ==
               {:error, %{exceeded_limits: [:monthly_pageview_limit]}}
    end
  end

  describe "monthly_pageview_limit/1" do
    test "is based on the plan if user is on a legacy plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @legacy_plan_id))

      assert Quota.monthly_pageview_limit(user.subscription) == 1_000_000
    end

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

  describe "team_member_usage/1" do
    test "returns the number of members in all of the sites the user owns" do
      me = insert(:user)

      _site_i_own_1 =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: build(:user), role: :viewer)
          ]
        )

      _site_i_own_2 =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: build(:user), role: :admin),
            build(:site_membership, user: build(:user), role: :viewer)
          ]
        )

      _site_i_own_3 =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner)
          ]
        )

      _site_i_have_access =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :viewer),
            build(:site_membership, user: build(:user), role: :viewer),
            build(:site_membership, user: build(:user), role: :viewer),
            build(:site_membership, user: build(:user), role: :viewer)
          ]
        )

      assert Quota.team_member_usage(me) == 3
    end

    test "counts the same email address as one team member" do
      me = insert(:user)
      joe = insert(:user, email: "joe@plausible.test")

      _site_i_own_1 =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: joe, role: :viewer)
          ]
        )

      _site_i_own_2 =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: build(:user), role: :admin),
            build(:site_membership, user: joe, role: :viewer)
          ]
        )

      site_i_own_3 = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      insert(:invitation, site: site_i_own_3, inviter: me, email: "joe@plausible.test")

      assert Quota.team_member_usage(me) == 2
    end

    test "counts pending invitations as team members" do
      me = insert(:user)
      member = insert(:user)

      site_i_own =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: member, role: :admin)
          ]
        )

      site_i_have_access =
        insert(:site, memberships: [build(:site_membership, user: me, role: :admin)])

      insert(:invitation, site: site_i_own, inviter: me)
      insert(:invitation, site: site_i_own, inviter: member)
      insert(:invitation, site: site_i_have_access, inviter: me)

      assert Quota.team_member_usage(me) == 3
    end

    test "does not count ownership transfer as a team member" do
      me = insert(:user)
      site_i_own = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      insert(:invitation, site: site_i_own, inviter: me, role: :owner)

      assert Quota.team_member_usage(me) == 0
    end

    test "returns zero when user does not have any site" do
      me = insert(:user)
      assert Quota.team_member_usage(me) == 0
    end

    test "does not count email report recipients as team members" do
      me = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      insert(:weekly_report,
        site: site,
        recipients: ["adam@plausible.test", "vini@plausible.test"]
      )

      assert Quota.team_member_usage(me) == 0
    end
  end

  describe "team_member_limit/1" do
    test "returns unlimited when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert :unlimited == Quota.team_member_limit(user_on_v1)
      assert :unlimited == Quota.team_member_limit(user_on_v2)
      assert :unlimited == Quota.team_member_limit(user_on_v3)
    end

    test "returns unlimited when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert :unlimited == Quota.team_member_limit(user)
    end

    test "returns 5 when user in on trial" do
      user =
        insert(:user,
          trial_expiry_date: Timex.shift(Timex.now(), days: 7)
        )

      assert 3 == Quota.team_member_limit(user)
    end

    test "returns unlimited when user in on trial but registered before the business tier was live" do
      user =
        insert(:user,
          trial_expiry_date: Timex.shift(Timex.now(), days: 7),
          inserted_at: ~U[2023-10-01T00:00:00Z]
        )

      assert :unlimited == Quota.team_member_limit(user)
    end

    test "returns the enterprise plan limit" do
      user =
        insert(:user,
          enterprise_plan:
            build(:enterprise_plan, paddle_plan_id: "123321", team_member_limit: 27),
          subscription: build(:subscription, paddle_plan_id: "123321")
        )

      assert 27 == Quota.team_member_limit(user)
    end

    test "reads from json file when the user is on a v4 plan" do
      user_on_growth = insert(:user, subscription: build(:growth_subscription))

      user_on_business = insert(:user, subscription: build(:business_subscription))

      assert 3 == Quota.team_member_limit(user_on_growth)
      assert 10 == Quota.team_member_limit(user_on_business)
    end

    test "returns unlimited when user is on a v3 business plan" do
      user =
        insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_business_plan_id))

      assert :unlimited == Quota.team_member_limit(user)
    end
  end

  describe "features_usage/1" do
    test "returns an empty list for a user/site who does not use any feature" do
      assert [] == Quota.features_usage(insert(:user))
      assert [] == Quota.features_usage(insert(:site))
    end

    test "returns [Props] when user/site uses custom props" do
      user = insert(:user)

      site =
        insert(:site,
          allowed_event_props: ["dummy"],
          memberships: [build(:site_membership, user: user, role: :owner)]
        )

      assert [Props] == Quota.features_usage(site)
      assert [Props] == Quota.features_usage(user)
    end

    on_full_build do
      test "returns [Funnels] when user/site uses funnels" do
        user = insert(:user)
        site = insert(:site, memberships: [build(:site_membership, user: user, role: :owner)])

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Funnels] == Quota.features_usage(site)
        assert [Funnels] == Quota.features_usage(user)
      end

      test "returns [RevenueGoals] when user/site uses revenue goals" do
        user = insert(:user)
        site = insert(:site, memberships: [build(:site_membership, user: user, role: :owner)])
        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        assert [RevenueGoals] == Quota.features_usage(site)
        assert [RevenueGoals] == Quota.features_usage(user)
      end
    end

    test "returns [StatsAPI] when user has a stats api key" do
      user = insert(:user)
      insert(:api_key, user: user)

      assert [StatsAPI] == Quota.features_usage(user)
    end

    on_full_build do
      test "returns multiple features" do
        user = insert(:user)

        site =
          insert(:site,
            allowed_event_props: ["dummy"],
            memberships: [build(:site_membership, user: user, role: :owner)]
          )

        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Props, Funnels, RevenueGoals] == Quota.features_usage(site)
        assert [Props, Funnels, RevenueGoals] == Quota.features_usage(user)
      end
    end

    test "accounts only for sites the user owns" do
      user = insert(:user)

      insert(:site,
        allowed_event_props: ["dummy"],
        memberships: [build(:site_membership, user: user, role: :admin)]
      )

      assert [] == Quota.features_usage(user)
    end
  end

  describe "allowed_features_for/1" do
    test "returns all grandfathered features when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert [Goals, Props, StatsAPI] == Quota.allowed_features_for(user_on_v1)
      assert [Goals, Props, StatsAPI] == Quota.allowed_features_for(user_on_v2)
      assert [Goals, Props, StatsAPI] == Quota.allowed_features_for(user_on_v3)
    end

    test "returns [Goals, Props, StatsAPI] when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert [Goals, Props, StatsAPI] == Quota.allowed_features_for(user)
    end

    on_full_build do
      test "returns the enterprise plan features" do
        user = insert(:user)

        enterprise_plan =
          insert(:enterprise_plan,
            user_id: user.id,
            monthly_pageview_limit: 100_000,
            site_limit: 500,
            features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels]
          )

        _subscription =
          insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

        assert [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels] ==
                 Quota.allowed_features_for(user)
      end
    end

    test "returns all features when user in on trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: 7))

      assert Plausible.Billing.Feature.list() == Quota.allowed_features_for(user)
    end

    test "returns previous plan limits for enterprise users who have not paid yet" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: @v1_plan_id)
        )

      assert [Goals, Props, StatsAPI] == Quota.allowed_features_for(user)
    end

    test "returns all features for enterprise users who have not upgraded yet and are on trial" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: nil
        )

      assert Plausible.Billing.Feature.list() == Quota.allowed_features_for(user)
    end

    test "returns old plan features for enterprise customers who are due to change a plan" do
      user =
        insert(:user,
          enterprise_plan:
            build(:enterprise_plan,
              paddle_plan_id: "old-paddle-plan-id",
              features: [Plausible.Billing.Feature.StatsAPI]
            ),
          subscription: build(:subscription, paddle_plan_id: "old-paddle-plan-id")
        )

      insert(:enterprise_plan, user_id: user.id, paddle_plan_id: "new-paddle-plan-id")
      assert [Plausible.Billing.Feature.StatsAPI] == Quota.allowed_features_for(user)
    end
  end

  describe "usage_cycle/1" do
    setup do
      user = insert(:user)
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:event, timestamp: ~N[2023-04-01 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-04-02 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-04-03 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-04-04 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-04-05 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-05-01 00:00:00], name: "pageview"),
        build(:event, timestamp: ~N[2023-05-02 00:00:00], name: "pageview"),
        build(:event, timestamp: ~N[2023-05-03 00:00:00], name: "pageview"),
        build(:event, timestamp: ~N[2023-05-04 00:00:00], name: "pageview"),
        build(:event, timestamp: ~N[2023-05-05 00:00:00], name: "pageview"),
        build(:event, timestamp: ~N[2023-06-01 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-06-02 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-06-03 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-06-04 00:00:00], name: "custom"),
        build(:event, timestamp: ~N[2023-06-05 00:00:00], name: "custom")
      ])

      {:ok, %{user: user}}
    end

    test "returns usage and date_range for the given billing month", %{user: user} do
      last_bill_date = ~D[2023-06-03]
      today = ~D[2023-06-05]

      insert(:subscription, user_id: user.id, last_bill_date: last_bill_date)

      assert %{date_range: penultimate_cycle, pageviews: 2, custom_events: 3, total: 5} =
               Quota.usage_cycle(user, :penultimate_cycle, today)

      assert %{date_range: last_cycle, pageviews: 3, custom_events: 2, total: 5} =
               Quota.usage_cycle(user, :last_cycle, today)

      assert %{date_range: current_cycle, pageviews: 0, custom_events: 3, total: 3} =
               Quota.usage_cycle(user, :current_cycle, today)

      assert penultimate_cycle == Date.range(~D[2023-04-03], ~D[2023-05-02])
      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
      assert current_cycle == Date.range(~D[2023-06-03], ~D[2023-07-02])
    end

    test "returns usage and date_range for the last 30 days", %{user: user} do
      today = ~D[2023-06-01]

      assert %{date_range: last_30_days, pageviews: 4, custom_events: 1, total: 5} =
               Quota.usage_cycle(user, :last_30_days, today)

      assert last_30_days == Date.range(~D[2023-05-02], ~D[2023-06-01])
    end

    test "only considers sites that the user owns", %{user: user} do
      different_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :admin)
          ]
        )

      populate_stats(different_site, [
        build(:event, timestamp: ~N[2023-05-05 00:00:00], name: "custom")
      ])

      last_bill_date = ~D[2023-06-03]
      today = ~D[2023-06-05]

      insert(:subscription, user_id: user.id, last_bill_date: last_bill_date)

      assert %{date_range: last_cycle, pageviews: 3, custom_events: 2, total: 5} =
               Quota.usage_cycle(user, :last_cycle, today)

      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
    end

    test "in case of yearly billing, cycles are normalized as if they were paying monthly" do
      last_bill_date = ~D[2020-09-01]
      today = ~D[2021-02-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      assert %{date_range: penultimate_cycle} =
               Quota.usage_cycle(user, :penultimate_cycle, today)

      assert %{date_range: last_cycle} =
               Quota.usage_cycle(user, :last_cycle, today)

      assert %{date_range: current_cycle} =
               Quota.usage_cycle(user, :current_cycle, today)

      assert penultimate_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert last_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
      assert current_cycle == Date.range(~D[2021-02-01], ~D[2021-02-28])
    end

    test "returns correct billing months when last_bill_date is the first day of the year" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      assert %{date_range: penultimate_cycle, total: 0} =
               Quota.usage_cycle(user, :penultimate_cycle, today)

      assert %{date_range: last_cycle, total: 0} =
               Quota.usage_cycle(user, :last_cycle, today)

      assert %{date_range: current_cycle, total: 0} =
               Quota.usage_cycle(user, :current_cycle, today)

      assert penultimate_cycle == Date.range(~D[2020-11-01], ~D[2020-11-30])
      assert last_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert current_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
    end
  end
end
