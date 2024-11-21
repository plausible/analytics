defmodule Plausible.Billing.QuotaTest do
  use Plausible.DataCase, async: true
  use Plausible
  alias Plausible.Billing.{Quota, Plans}
  alias Plausible.Billing.Feature.{Goals, Props, StatsAPI}

  use Plausible.Teams.Test

  on_ee do
    alias Plausible.Billing.Feature.Funnels
    alias Plausible.Billing.Feature.RevenueGoals
  end

  @legacy_plan_id "558746"
  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_plan_id "749342"
  @v3_business_plan_id "857481"
  @v4_1m_plan_id "857101"
  @v4_10m_growth_plan_id "857104"
  @v4_10m_business_plan_id "857112"

  describe "site_limit/1" do
    @describetag :ee_only

    test "returns 50 when user is on an old plan" do
      user_on_v1 = new_user() |> subscribe_to_plan(@v1_plan_id)
      user_on_v2 = new_user() |> subscribe_to_plan(@v2_plan_id)
      user_on_v3 = new_user() |> subscribe_to_plan(@v3_plan_id)

      assert 50 == Plausible.Teams.Adapter.Read.Billing.site_limit(user_on_v1)
      assert 50 == Plausible.Teams.Adapter.Read.Billing.site_limit(user_on_v2)
      assert 50 == Plausible.Teams.Adapter.Read.Billing.site_limit(user_on_v3)
    end

    test "returns 50 when user is on free_10k plan" do
      user = new_user() |> subscribe_to_plan("free_10k")
      assert 50 == Plausible.Teams.Adapter.Read.Billing.site_limit(user)
    end

    test "returns the configured site limit for enterprise plan" do
      user = new_user() |> subscribe_to_enterprise_plan(site_limit: 500)
      assert Plausible.Teams.Adapter.Read.Billing.site_limit(user) == 500
    end

    test "returns 10 when user in on trial" do
      user = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: 7))
      assert Plausible.Teams.Adapter.Read.Billing.site_limit(user) == 10
    end

    test "returns the subscription limit for enterprise users who have not paid yet" do
      user =
        new_user()
        |> subscribe_to_plan(@v1_plan_id)
        |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", subscription?: false)

      assert Plausible.Teams.Adapter.Read.Billing.site_limit(user) == 50
    end

    test "returns 10 for enterprise users who have not upgraded yet and are on trial" do
      user =
        new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", subscription?: false)

      assert Plausible.Teams.Adapter.Read.Billing.site_limit(user) == 10
    end
  end

  test "site_usage/1 returns the amount of sites the user owns" do
    user = insert(:user)
    insert_list(3, :site, memberships: [build(:site_membership, user: user, role: :owner)])
    insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])
    insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

    assert Quota.Usage.site_usage(user) == 3
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

  describe "ensure_within_plan_limits/2" do
    test "returns :ok when site and team member limits are reached but not exceeded" do
      usage = %{
        monthly_pageviews: %{last_30_days: %{total: 1}},
        team_members: 3,
        sites: 10
      }

      plan = Plans.find(@v4_1m_plan_id)

      assert Quota.ensure_within_plan_limits(usage, plan) == :ok
    end

    test "returns all exceeded limits" do
      usage = %{
        monthly_pageviews: %{last_30_days: %{total: 1_150_001}},
        team_members: 4,
        sites: 11
      }

      plan = Plans.find(@v4_1m_plan_id)

      {:error, {:over_plan_limits, exceeded_limits}} =
        Quota.ensure_within_plan_limits(usage, plan)

      assert :monthly_pageview_limit in exceeded_limits
      assert :team_member_limit in exceeded_limits
      assert :site_limit in exceeded_limits
    end

    test "can skip checking the pageview limit" do
      usage = %{
        monthly_pageviews: %{last_30_days: %{total: 1_150_001}},
        team_members: 2,
        sites: 8
      }

      plan = Plans.find(@v4_1m_plan_id)

      assert :ok = Quota.ensure_within_plan_limits(usage, plan, ignore_pageview_limit: true)
    end

    test "by the last 30 days usage, pageview limit is exceeded when more than 10% over the limit" do
      usage_within_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 1_100_000}},
        team_members: 1,
        sites: 1
      }

      usage_over_pageview_limit = %{
        monthly_pageviews: %{last_30_days: %{total: 1_100_001}},
        team_members: 1,
        sites: 1
      }

      plan = Plans.find(@v4_1m_plan_id)

      assert Quota.ensure_within_plan_limits(usage_within_pageview_limit, plan) == :ok

      assert Quota.ensure_within_plan_limits(usage_over_pageview_limit, plan) ==
               {:error, {:over_plan_limits, [:monthly_pageview_limit]}}
    end

    test "by billing cycles usage, pageview limit is exceeded when last two billing cycles exceed by 10%" do
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

      assert Quota.ensure_within_plan_limits(usage_within_pageview_limit, plan) == :ok

      assert Quota.ensure_within_plan_limits(usage_over_pageview_limit, plan) ==
               {:error, {:over_plan_limits, [:monthly_pageview_limit]}}
    end

    test "returns error with exceeded limits for enterprise plans" do
      user = insert(:user)

      usage = %{
        monthly_pageviews: %{penultimate_cycle: %{total: 1}, last_cycle: %{total: 1}},
        team_members: 1,
        sites: 2
      }

      enterprise_plan =
        insert(:enterprise_plan,
          user: user,
          paddle_plan_id: "whatever",
          site_limit: 1
        )

      assert Quota.ensure_within_plan_limits(usage, enterprise_plan) ==
               {:error, {:over_plan_limits, [:site_limit]}}
    end
  end

  describe "monthly_pageview_limit/1" do
    test "is based on the plan if user is on a legacy plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @legacy_plan_id))

      assert Quota.Limits.monthly_pageview_limit(user.subscription) == 1_000_000
    end

    test "is based on the plan if user is on a standard plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert Quota.Limits.monthly_pageview_limit(user.subscription) == 10_000
    end

    test "free_10k has 10k monthly_pageview_limit" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Quota.Limits.monthly_pageview_limit(user.subscription) == 10_000
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan =
        insert(:enterprise_plan, user_id: user.id, monthly_pageview_limit: 100_000)

      subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert Quota.Limits.monthly_pageview_limit(subscription) == 100_000
    end

    test "does not limit pageviews when user has a pending enterprise plan" do
      user = insert(:user)
      subscription = insert(:subscription, user_id: user.id, paddle_plan_id: "pending-enterprise")

      assert Quota.Limits.monthly_pageview_limit(subscription) == :unlimited
    end
  end

  describe "team_member_usage/2" do
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

      assert Quota.Usage.team_member_usage(me) == 3
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

      assert Quota.Usage.team_member_usage(me) == 2
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

      assert Quota.Usage.team_member_usage(me) == 3
    end

    test "does not count ownership transfer as a team member by default" do
      me = insert(:user)
      site_i_own = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      insert(:invitation, site: site_i_own, inviter: me, role: :owner)

      assert Quota.Usage.team_member_usage(me) == 0
    end

    test "counts team members from pending ownerships when specified" do
      me = insert(:user)

      user_1 = insert(:user)
      user_2 = insert(:user)

      pending_ownership_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user_1, role: :owner),
            build(:site_membership, user: user_2, role: :admin)
          ]
        )

      insert(:invitation,
        site: pending_ownership_site,
        inviter: user_1,
        email: me.email,
        role: :owner
      )

      assert Quota.Usage.team_member_usage(me,
               pending_ownership_site_ids: [pending_ownership_site.id]
             ) == 2
    end

    test "counts invitations towards team members from pending ownership sites" do
      me = insert(:user)

      user_1 = insert(:user)
      user_2 = insert(:user)

      pending_ownership_site =
        insert(:site,
          memberships: [build(:site_membership, user: user_1, role: :owner)]
        )

      insert(:invitation,
        site: pending_ownership_site,
        inviter: user_1,
        email: me.email,
        role: :owner
      )

      insert(:invitation,
        site: pending_ownership_site,
        inviter: user_1,
        email: user_2.email,
        role: :admin
      )

      assert Quota.Usage.team_member_usage(me,
               pending_ownership_site_ids: [pending_ownership_site.id]
             ) == 2
    end

    test "returns zero when user does not have any site" do
      me = insert(:user)
      assert Quota.Usage.team_member_usage(me) == 0
    end

    test "does not count email report recipients as team members" do
      me = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      insert(:weekly_report,
        site: site,
        recipients: ["adam@plausible.test", "vini@plausible.test"]
      )

      assert Quota.Usage.team_member_usage(me) == 0
    end

    test "excludes specific emails from limit calculation" do
      me = insert(:user)
      member = insert(:user)

      site_i_own =
        insert(:site,
          memberships: [
            build(:site_membership, user: me, role: :owner),
            build(:site_membership, user: member, role: :admin)
          ]
        )

      insert(:invitation, site: site_i_own, inviter: me)
      insert(:invitation, site: site_i_own, inviter: member)
      invitation = insert(:invitation, site: site_i_own, inviter: me, email: "foo@example.com")

      assert Quota.Usage.team_member_usage(me) == 4
      assert Quota.Usage.team_member_usage(me, exclude_emails: ["arbitrary@example.com"]) == 4
      assert Quota.Usage.team_member_usage(me, exclude_emails: [member.email]) == 3
      assert Quota.Usage.team_member_usage(me, exclude_emails: [invitation.email]) == 3

      assert Quota.Usage.team_member_usage(me, exclude_emails: [member.email, invitation.email]) ==
               2
    end
  end

  describe "team_member_limit/1" do
    @describetag :ee_only
    test "returns unlimited when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert :unlimited == Quota.Limits.team_member_limit(user_on_v1)
      assert :unlimited == Quota.Limits.team_member_limit(user_on_v2)
      assert :unlimited == Quota.Limits.team_member_limit(user_on_v3)
    end

    test "returns unlimited when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert :unlimited == Quota.Limits.team_member_limit(user)
    end

    test "returns 5 when user in on trial" do
      user =
        insert(:user,
          trial_expiry_date: Timex.shift(Timex.now(), days: 7)
        )

      assert 3 == Quota.Limits.team_member_limit(user)
    end

    test "returns the enterprise plan limit" do
      user =
        insert(:user,
          enterprise_plan:
            build(:enterprise_plan, paddle_plan_id: "123321", team_member_limit: 27),
          subscription: build(:subscription, paddle_plan_id: "123321")
        )

      assert 27 == Quota.Limits.team_member_limit(user)
    end

    test "reads from json file when the user is on a v4 plan" do
      user_on_growth = insert(:user, subscription: build(:growth_subscription))

      user_on_business = insert(:user, subscription: build(:business_subscription))

      assert 3 == Quota.Limits.team_member_limit(user_on_growth)
      assert 10 == Quota.Limits.team_member_limit(user_on_business)
    end

    test "returns unlimited when user is on a v3 business plan" do
      user =
        insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_business_plan_id))

      assert :unlimited == Quota.Limits.team_member_limit(user)
    end
  end

  describe "features_usage/2" do
    test "returns an empty list for a user/site who does not use any feature" do
      assert [] == Quota.Usage.features_usage(insert(:user))
      assert [] == Quota.Usage.features_usage(nil, [insert(:site).id])
    end

    test "returns [Props] when user/site uses custom props" do
      user = insert(:user)

      site =
        insert(:site,
          allowed_event_props: ["dummy"],
          memberships: [build(:site_membership, user: user, role: :owner)]
        )

      assert [Props] == Quota.Usage.features_usage(nil, [site.id])
      assert [Props] == Quota.Usage.features_usage(user)
    end

    on_ee do
      test "returns [Funnels] when user/site uses funnels" do
        user = new_user()
        site = new_site(owner: user)

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Funnels] == Quota.Usage.features_usage(nil, [site.id])
        assert [Funnels] == Quota.Usage.features_usage(user)
      end

      test "returns [RevenueGoals] when user/site uses revenue goals" do
        user = insert(:user)
        site = insert(:site, memberships: [build(:site_membership, user: user, role: :owner)])
        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        assert [RevenueGoals] == Quota.Usage.features_usage(nil, [site.id])
        assert [RevenueGoals] == Quota.Usage.features_usage(user)
      end
    end

    test "returns [StatsAPI] when user has a stats api key" do
      user = insert(:user)
      insert(:api_key, user: user)

      assert [StatsAPI] == Quota.Usage.features_usage(user)
    end

    test "returns feature usage based on a user and a custom list of site_ids" do
      user = insert(:user)
      insert(:api_key, user: user)

      site_using_props = insert(:site, allowed_event_props: ["dummy"])

      site_ids = [site_using_props.id]
      assert [Props, StatsAPI] == Quota.Usage.features_usage(user, site_ids)
    end

    on_ee do
      test "returns multiple features used by the user" do
        user = new_user()
        insert(:api_key, user: user)

        site =
          new_site(
            allowed_event_props: ["dummy"],
            owner: user
          )

        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Props, Funnels, RevenueGoals, StatsAPI] == Quota.Usage.features_usage(user)
      end
    end

    test "accounts only for sites the user owns" do
      user = insert(:user)

      insert(:site,
        allowed_event_props: ["dummy"],
        memberships: [build(:site_membership, user: user, role: :admin)]
      )

      assert [] == Quota.Usage.features_usage(user)
    end
  end

  describe "allowed_features_for/1" do
    on_ee do
      test "users with expired trials have no access to subscription features" do
        user = insert(:user, trial_expiry_date: ~D[2023-01-01])
        assert [Goals] == Quota.Limits.allowed_features_for(user)
      end
    end

    test "returns all grandfathered features when user is on an old plan" do
      user_on_v1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      user_on_v2 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      user_on_v3 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_plan_id))

      assert [Goals, Props, StatsAPI] == Quota.Limits.allowed_features_for(user_on_v1)
      assert [Goals, Props, StatsAPI] == Quota.Limits.allowed_features_for(user_on_v2)
      assert [Goals, Props, StatsAPI] == Quota.Limits.allowed_features_for(user_on_v3)
    end

    test "returns [Goals, Props, StatsAPI] when user is on free_10k plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))
      assert [Goals, Props, StatsAPI] == Quota.Limits.allowed_features_for(user)
    end

    on_ee do
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
                 Quota.Limits.allowed_features_for(user)
      end
    end

    test "returns all features when user in on trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: 7))

      assert Plausible.Billing.Feature.list() == Quota.Limits.allowed_features_for(user)
    end

    test "returns previous plan limits for enterprise users who have not paid yet" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: @v1_plan_id)
        )

      assert [Goals, Props, StatsAPI] == Quota.Limits.allowed_features_for(user)
    end

    test "returns all features for enterprise users who have not upgraded yet and are on trial" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: nil
        )

      assert Plausible.Billing.Feature.list() == Quota.Limits.allowed_features_for(user)
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
      assert [Plausible.Billing.Feature.StatsAPI] == Quota.Limits.allowed_features_for(user)
    end
  end

  describe "monthly_pageview_usage/2" do
    test "returns empty usage for user without subscription and without any sites" do
      user =
        insert(:user)
        |> Plausible.Users.with_subscription()

      assert %{
               last_30_days: %{
                 total: 0,
                 custom_events: 0,
                 pageviews: 0,
                 date_range: date_range
               }
             } = Quota.Usage.monthly_pageview_usage(user)

      assert date_range.last == Date.utc_today()
      assert Date.compare(date_range.first, date_range.last) == :lt
    end

    test "returns usage for user without subscription with a site" do
      user =
        insert(:user)
        |> Plausible.Users.with_subscription()

      site = insert(:site, members: [user])

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:event, timestamp: Timex.shift(now, days: -40), name: "custom"),
        build(:event, timestamp: Timex.shift(now, days: -10), name: "custom"),
        build(:event, timestamp: Timex.shift(now, days: -9), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -8), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -7), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -6), name: "custom")
      ])

      assert %{
               last_30_days: %{
                 total: 5,
                 custom_events: 2,
                 pageviews: 3,
                 date_range: %{}
               }
             } = Quota.Usage.monthly_pageview_usage(user)
    end

    test "pageleave events are not counted towards monthly pageview usage" do
      user = insert(:user) |> Plausible.Users.with_subscription()
      site = insert(:site, members: [user])
      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:event, timestamp: Timex.shift(now, days: -8), name: "custom"),
        build(:pageview, user_id: 199, timestamp: Timex.shift(now, days: -5, minutes: -2)),
        build(:pageleave, user_id: 199, timestamp: Timex.shift(now, days: -5))
      ])

      assert %{
               last_30_days: %{
                 total: 2,
                 custom_events: 1,
                 pageviews: 1,
                 date_range: %{}
               }
             } = Quota.Usage.monthly_pageview_usage(user)
    end

    test "returns usage for user with subscription and a site" do
      today = Date.utc_today()

      user =
        insert(:user,
          subscription: build(:subscription, last_bill_date: Timex.shift(today, days: -8))
        )

      site = insert(:site, members: [user])

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:event, timestamp: Timex.shift(now, days: -40), name: "custom"),
        build(:event, timestamp: Timex.shift(now, days: -10), name: "custom"),
        build(:event, timestamp: Timex.shift(now, days: -9), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -8), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -7), name: "pageview"),
        build(:event, timestamp: Timex.shift(now, days: -6), name: "custom")
      ])

      assert %{
               current_cycle: %{
                 total: 3,
                 custom_events: 1,
                 pageviews: 2,
                 date_range: %{}
               },
               last_cycle: %{
                 total: 2,
                 custom_events: 1,
                 pageviews: 1,
                 date_range: %{}
               },
               penultimate_cycle: %{
                 total: 1,
                 custom_events: 1,
                 pageviews: 0,
                 date_range: %{}
               }
             } = Quota.Usage.monthly_pageview_usage(user)
    end

    test "returns usage for only a subset of site IDs" do
      today = Date.utc_today()

      user =
        insert(:user,
          subscription: build(:subscription, last_bill_date: Timex.shift(today, days: -8))
        )

      site1 = insert(:site, members: [user])
      site2 = insert(:site, members: [user])
      site3 = insert(:site, members: [user])

      now = NaiveDateTime.utc_now()

      for site <- [site1, site2, site3] do
        populate_stats(site, [
          build(:event, timestamp: Timex.shift(now, days: -40), name: "custom"),
          build(:event, timestamp: Timex.shift(now, days: -10), name: "custom"),
          build(:event, timestamp: Timex.shift(now, days: -9), name: "pageview"),
          build(:event, timestamp: Timex.shift(now, days: -8), name: "pageview"),
          build(:event, timestamp: Timex.shift(now, days: -7), name: "pageview"),
          build(:event, timestamp: Timex.shift(now, days: -6), name: "custom")
        ])
      end

      assert %{
               current_cycle: %{
                 total: 6,
                 custom_events: 2,
                 pageviews: 4,
                 date_range: %{}
               },
               last_cycle: %{
                 total: 4,
                 custom_events: 2,
                 pageviews: 2,
                 date_range: %{}
               },
               penultimate_cycle: %{
                 total: 2,
                 custom_events: 2,
                 pageviews: 0,
                 date_range: %{}
               }
             } = Quota.Usage.monthly_pageview_usage(user, [site1.id, site3.id])
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
               Quota.Usage.usage_cycle(user, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle, pageviews: 3, custom_events: 2, total: 5} =
               Quota.Usage.usage_cycle(user, :last_cycle, nil, today)

      assert %{date_range: current_cycle, pageviews: 0, custom_events: 3, total: 3} =
               Quota.Usage.usage_cycle(user, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2023-04-03], ~D[2023-05-02])
      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
      assert current_cycle == Date.range(~D[2023-06-03], ~D[2023-07-02])
    end

    test "returns usage and date_range for the last 30 days", %{user: user} do
      today = ~D[2023-06-01]

      assert %{date_range: last_30_days, pageviews: 4, custom_events: 1, total: 5} =
               Quota.Usage.usage_cycle(user, :last_30_days, nil, today)

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
               Quota.Usage.usage_cycle(user, :last_cycle, nil, today)

      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
    end

    test "in case of yearly billing, cycles are normalized as if they were paying monthly" do
      last_bill_date = ~D[2020-09-01]
      today = ~D[2021-02-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      assert %{date_range: penultimate_cycle} =
               Quota.Usage.usage_cycle(user, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle} =
               Quota.Usage.usage_cycle(user, :last_cycle, nil, today)

      assert %{date_range: current_cycle} =
               Quota.Usage.usage_cycle(user, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert last_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
      assert current_cycle == Date.range(~D[2021-02-01], ~D[2021-02-28])
    end

    test "returns correct billing months when last_bill_date is the first day of the year" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      assert %{date_range: penultimate_cycle, total: 0} =
               Quota.Usage.usage_cycle(user, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle, total: 0} =
               Quota.Usage.usage_cycle(user, :last_cycle, nil, today)

      assert %{date_range: current_cycle, total: 0} =
               Quota.Usage.usage_cycle(user, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2020-11-01], ~D[2020-11-30])
      assert last_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert current_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
    end
  end

  describe "suggest_tier/2" do
    setup do
      %{user: insert(:user) |> Plausible.Users.with_subscription()}
    end

    test "returns nil if the monthly pageview limit exceeds regular plans",
         %{user: user} do
      highest_growth_plan = Plausible.Billing.Plans.find(@v4_10m_growth_plan_id)
      highest_business_plan = Plausible.Billing.Plans.find(@v4_10m_business_plan_id)

      usage =
        Quota.Usage.usage(user)
        |> Map.replace!(:monthly_pageviews, %{last_30_days: %{total: 12_000_000}})

      suggested_tier =
        usage
        |> Quota.suggest_tier(highest_growth_plan, highest_business_plan)

      assert suggested_tier == nil
    end
  end
end
