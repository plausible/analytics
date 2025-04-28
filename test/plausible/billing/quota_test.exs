defmodule Plausible.Billing.QuotaTest do
  alias Plausible.Billing.EnterprisePlan
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
  @v4_1m_plan_id "857101"
  @v4_10m_growth_plan_id "857104"
  @v4_10m_business_plan_id "857112"

  @highest_growth_plan Plausible.Billing.Plans.find(@v4_10m_growth_plan_id)
  @highest_business_plan Plausible.Billing.Plans.find(@v4_10m_business_plan_id)

  on_ee do
    @v3_business_plan_id "857481"

    describe "site_limit/1" do
      test "returns 50 when user is on an old plan" do
        team_on_v1 = new_user() |> subscribe_to_plan(@v1_plan_id) |> team_of()
        team_on_v2 = new_user() |> subscribe_to_plan(@v2_plan_id) |> team_of()
        team_on_v3 = new_user() |> subscribe_to_plan(@v3_plan_id) |> team_of()

        assert 50 == Plausible.Teams.Billing.site_limit(team_on_v1)
        assert 50 == Plausible.Teams.Billing.site_limit(team_on_v2)
        assert 50 == Plausible.Teams.Billing.site_limit(team_on_v3)
      end

      test "returns 50 when user is on free_10k plan" do
        team = new_user() |> subscribe_to_plan("free_10k") |> team_of()
        assert 50 == Plausible.Teams.Billing.site_limit(team)
      end

      test "returns the configured site limit for enterprise plan" do
        team = new_user() |> subscribe_to_enterprise_plan(site_limit: 500) |> team_of()
        assert Plausible.Teams.Billing.site_limit(team) == 500
      end

      test "returns 10 when user in on trial" do
        team = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: 7)) |> team_of()
        assert Plausible.Teams.Billing.site_limit(team) == 10
      end

      test "returns the subscription limit for enterprise users who have not paid yet" do
        team =
          new_user()
          |> subscribe_to_plan(@v1_plan_id)
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", subscription?: false)
          |> team_of()

        assert Plausible.Teams.Billing.site_limit(team) == 50
      end

      test "returns 10 for enterprise users who have not upgraded yet and are on trial" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", subscription?: false)
          |> team_of()

        assert Plausible.Teams.Billing.site_limit(team) == 10
      end

      test "grandfathered site limit should be unlimited when accepting transfer invitations" do
        # must be before ~D[2021-05-05]
        owner = new_user(team: [inserted_at: ~N[2021-01-01 00:00:00]])
        # plan with site_limit: 10
        subscribe_to_plan(owner, "857097")
        _site = for _ <- 1..10, do: new_site(owner: owner)

        other_owner = new_user()
        other_site = new_site(owner: other_owner)
        invite_transfer(other_site, owner, inviter: other_owner)

        team = owner |> team_of()

        assert Plausible.Teams.Billing.site_limit(team) == :unlimited
        assert Plausible.Teams.Invitations.ensure_can_take_ownership(other_site, team) == :ok
      end
    end
  end

  test "site_usage/1 returns the amount of sites the user owns" do
    user = new_user()
    for _ <- 1..3, do: new_site(owner: user)
    add_guest(new_site(), user: user, role: :editor)
    add_guest(new_site(), user: user, role: :viewer)
    team = team_of(user)

    assert Plausible.Teams.Billing.site_usage(team) == 3
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
      user = new_user()

      usage = %{
        monthly_pageviews: %{penultimate_cycle: %{total: 1}, last_cycle: %{total: 1}},
        team_members: 1,
        sites: 2
      }

      subscribe_to_enterprise_plan(user,
        subscription?: false,
        paddle_plan_id: "whatever",
        site_limit: 1
      )

      enterprise_plan = Repo.get_by!(EnterprisePlan, paddle_plan_id: "whatever")

      assert Quota.ensure_within_plan_limits(usage, enterprise_plan) ==
               {:error, {:over_plan_limits, [:site_limit]}}
    end
  end

  describe "monthly_pageview_limit/1" do
    test "is based on the plan if user is on a legacy plan" do
      team =
        new_user()
        |> subscribe_to_plan(@legacy_plan_id)
        |> team_of()
        |> Plausible.Teams.with_subscription()

      assert Plausible.Teams.Billing.monthly_pageview_limit(team.subscription) == 1_000_000
    end

    test "is based on the plan if user is on a standard plan" do
      team =
        new_user()
        |> subscribe_to_plan(@v1_plan_id)
        |> team_of()
        |> Plausible.Teams.with_subscription()

      assert Plausible.Teams.Billing.monthly_pageview_limit(team.subscription) == 10_000
    end

    test "free_10k has 10k monthly_pageview_limit" do
      team =
        new_user()
        |> subscribe_to_plan("free_10k")
        |> team_of()
        |> Plausible.Teams.with_subscription()

      assert Plausible.Teams.Billing.monthly_pageview_limit(team.subscription) == 10_000
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = new_user()

      subscription =
        user
        |> subscribe_to_enterprise_plan(monthly_pageview_limit: 100_000)
        |> team_of()
        |> Repo.preload(:subscription)
        |> Map.fetch!(:subscription)

      assert Plausible.Teams.Billing.monthly_pageview_limit(subscription) == 100_000
    end

    test "does not limit pageviews when user has a pending enterprise plan" do
      user = new_user()

      subscription =
        user
        |> subscribe_to_plan("pending-enterprise")
        |> team_of()
        |> Repo.preload(:subscription)
        |> Map.fetch!(:subscription)

      assert Plausible.Teams.Billing.monthly_pageview_limit(subscription) == :unlimited
    end
  end

  describe "team_member_usage/2" do
    test "returns the number of members in all of the sites the user owns" do
      me = new_user()
      site_i_own_1 = new_site(owner: me)
      add_guest(site_i_own_1, role: :viewer)
      site_i_own_2 = new_site(owner: me)
      add_guest(site_i_own_2, role: :editor)
      add_guest(site_i_own_2, role: :viewer)
      _site_i_own_3 = new_site(owner: me)
      site_i_have_access = new_site()
      add_guest(site_i_have_access, user: me, role: :viewer)
      add_guest(site_i_have_access, role: :viewer)
      add_guest(site_i_have_access, role: :viewer)
      add_guest(site_i_have_access, role: :viewer)
      team = team_of(me)

      assert Plausible.Teams.Billing.team_member_usage(team) == 3
    end

    test "counts the same email address as one team member" do
      me = new_user()
      joe = new_user(email: "joe@plausible.test")
      site_i_own_1 = new_site(owner: me)
      add_guest(site_i_own_1, user: joe, role: :viewer)
      site_i_own_2 = new_site(owner: me)
      add_guest(site_i_own_2, user: new_user(), role: :editor)
      add_guest(site_i_own_2, user: joe, role: :viewer)
      site_i_own_3 = new_site(owner: me)
      invite_guest(site_i_own_3, joe, role: :viewer, inviter: me)
      team = team_of(me)

      assert Plausible.Teams.Billing.team_member_usage(team) == 2
    end

    test "counts pending invitations as team members" do
      me = new_user()
      member = new_user()
      site_i_own = new_site(owner: me)
      add_guest(site_i_own, user: member, role: :editor)
      site_i_have_access = new_site()
      add_guest(site_i_have_access, user: me, role: :editor)
      team = team_of(me)

      invite_guest(site_i_own, new_user(), role: :viewer, inviter: me)
      invite_guest(site_i_own, new_user(), role: :viewer, inviter: member)
      invite_guest(site_i_have_access, new_user(), role: :viewer, inviter: me)

      assert Plausible.Teams.Billing.team_member_usage(team) == 3
    end

    test "does not count ownership transfer as a team member by default" do
      me = new_user()
      site_i_own = new_site(owner: me)
      invite_transfer(site_i_own, new_user(), inviter: me)
      team = team_of(me)

      assert Plausible.Teams.Billing.team_member_usage(team) == 0
    end

    test "counts team members from pending ownerships when specified" do
      me = new_user(trial_expiry_date: Date.utc_today())
      my_team = team_of(me)

      user_1 = new_user()
      user_2 = new_user()

      pending_ownership_site = new_site(owner: user_1)
      add_guest(pending_ownership_site, user: user_2, role: :editor)

      invite_transfer(pending_ownership_site, me, inviter: user_1)

      assert Plausible.Teams.Billing.team_member_usage(my_team,
               pending_ownership_site_ids: [pending_ownership_site.id]
             ) == 2
    end

    test "counts invitations towards team members from pending ownership sites" do
      me = new_user(trial_expiry_date: Date.utc_today())
      user_1 = new_user()
      user_2 = new_user()
      pending_ownership_site = new_site(owner: user_1)
      invite_transfer(pending_ownership_site, me, inviter: user_1)
      invite_guest(pending_ownership_site, user_2, role: :editor, inviter: user_1)
      team = team_of(me)

      assert Plausible.Teams.Billing.team_member_usage(team,
               pending_ownership_site_ids: [pending_ownership_site.id]
             ) == 2
    end

    test "returns zero when user does not have any site" do
      team = new_user() |> team_of()
      assert Plausible.Teams.Billing.team_member_usage(team) == 0
    end

    test "does not count email report recipients as team members" do
      me = new_user()
      site = new_site(owner: me)
      team = team_of(me)

      insert(:weekly_report,
        site: site,
        recipients: ["adam@plausible.test", "vini@plausible.test"]
      )

      assert Plausible.Teams.Billing.team_member_usage(team) == 0
    end

    test "excludes specific emails from limit calculation" do
      me = new_user()
      member = new_user()
      site_i_own = new_site(owner: me)
      add_guest(site_i_own, user: member, role: :editor)
      team = team_of(me)

      invite_guest(site_i_own, new_user(), role: :viewer, inviter: me)
      invite_guest(site_i_own, new_user(), role: :viewer, inviter: member)
      invitation = invite_guest(site_i_own, "foo@example.com", role: :viewer, inviter: me)

      assert Plausible.Teams.Billing.team_member_usage(team) == 4

      assert Plausible.Teams.Billing.team_member_usage(team,
               exclude_emails: ["arbitrary@example.com"]
             ) == 4

      assert Plausible.Teams.Billing.team_member_usage(team, exclude_emails: [member.email]) == 3

      assert Plausible.Teams.Billing.team_member_usage(team,
               exclude_emails: [invitation.team_invitation.email]
             ) ==
               3

      assert Plausible.Teams.Billing.team_member_usage(team,
               exclude_emails: [member.email, invitation.team_invitation.email]
             ) == 2
    end
  end

  on_ee do
    describe "team_member_limit/1" do
      test "returns unlimited when user is on an old plan" do
        team_on_v1 = new_user() |> subscribe_to_plan(@v1_plan_id) |> team_of()
        team_on_v2 = new_user() |> subscribe_to_plan(@v2_plan_id) |> team_of()
        team_on_v3 = new_user() |> subscribe_to_plan(@v3_plan_id) |> team_of()

        assert :unlimited == Plausible.Teams.Billing.team_member_limit(team_on_v1)
        assert :unlimited == Plausible.Teams.Billing.team_member_limit(team_on_v2)
        assert :unlimited == Plausible.Teams.Billing.team_member_limit(team_on_v3)
      end

      test "returns unlimited when user is on free_10k plan" do
        user = new_user()
        subscribe_to_plan(user, "free_10k")
        team = team_of(user)
        assert :unlimited == Plausible.Teams.Billing.team_member_limit(team)
      end

      test "returns 5 when user in on trial" do
        team = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: 7)) |> team_of()

        assert 3 == Plausible.Teams.Billing.team_member_limit(team)
      end

      test "returns the enterprise plan limit" do
        user = new_user()
        subscribe_to_enterprise_plan(user, team_member_limit: 27)
        team = team_of(user)

        assert 27 == Plausible.Teams.Billing.team_member_limit(team)
      end

      test "reads from json file when the user is on a v4 plan" do
        team_on_growth = new_user() |> subscribe_to_growth_plan() |> team_of()
        team_on_business = new_user() |> subscribe_to_business_plan() |> team_of()

        assert 3 == Plausible.Teams.Billing.team_member_limit(team_on_growth)
        assert 10 == Plausible.Teams.Billing.team_member_limit(team_on_business)
      end

      test "returns unlimited when user is on a v3 business plan" do
        team = new_user() |> subscribe_to_plan(@v3_business_plan_id) |> team_of()

        assert :unlimited == Plausible.Teams.Billing.team_member_limit(team)
      end
    end
  end

  describe "features_usage/2" do
    test "returns an empty list for a user/site who does not use any feature" do
      assert [] == Plausible.Teams.Billing.features_usage(team_of(new_user()))
      assert [] == Plausible.Teams.Billing.features_usage(nil, [new_site().id])
    end

    test "returns [Props] when user/site uses custom props" do
      user = new_user()
      site = new_site(owner: user, allowed_event_props: ["dummy"])
      team = team_of(user)

      assert [Props] == Plausible.Teams.Billing.features_usage(nil, [site.id])
      assert [Props] == Plausible.Teams.Billing.features_usage(team)
    end

    on_ee do
      test "returns [Funnels] when user/site uses funnels" do
        user = new_user()
        site = new_site(owner: user)
        team = team_of(user)

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Funnels] == Plausible.Teams.Billing.features_usage(nil, [site.id])
        assert [Funnels] == Plausible.Teams.Billing.features_usage(team)
      end

      test "returns [RevenueGoals] when user/site uses revenue goals" do
        user = new_user(trial_expiry_date: Date.utc_today())
        team = team_of(user)
        site = new_site(owner: user)
        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        assert [RevenueGoals] == Plausible.Teams.Billing.features_usage(nil, [site.id])
        assert [RevenueGoals] == Plausible.Teams.Billing.features_usage(team)
      end
    end

    test "returns [StatsAPI] when user has a stats api key" do
      user = new_user(trial_expiry_date: Date.utc_today())
      team = team_of(user)
      insert(:api_key, user: user)

      assert [StatsAPI] == Plausible.Teams.Billing.features_usage(team)
    end

    test "returns feature usage based on a user and a custom list of site_ids" do
      user = new_user(trial_expiry_date: Date.utc_today())
      team = team_of(user)
      insert(:api_key, user: user)
      site_using_props = new_site(allowed_event_props: ["dummy"])

      site_ids = [site_using_props.id]
      assert [Props, StatsAPI] == Plausible.Teams.Billing.features_usage(team, site_ids)
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

        team = team_of(user)

        insert(:goal, currency: :USD, site: site, event_name: "Purchase")

        goals = insert_list(3, :goal, site: site, event_name: fn -> Ecto.UUID.generate() end)
        steps = Enum.map(goals, &%{"goal_id" => &1.id})
        Plausible.Funnels.create(site, "dummy", steps)

        assert [Props, Funnels, RevenueGoals, StatsAPI] ==
                 Plausible.Teams.Billing.features_usage(team)
      end
    end

    test "accounts only for sites the user owns" do
      assert [] == Plausible.Teams.Billing.features_usage(nil)
    end
  end

  describe "allowed_features_for/1" do
    on_ee do
      test "users with expired trials have no access to subscription features" do
        team = new_user(trial_expiry_date: ~D[2023-01-01]) |> team_of()
        assert [Goals] == Plausible.Teams.Billing.allowed_features_for(team)
      end
    end

    test "returns all grandfathered features when user is on an old plan" do
      team_on_v1 = new_user() |> subscribe_to_plan(@v1_plan_id) |> team_of()
      team_on_v2 = new_user() |> subscribe_to_plan(@v2_plan_id) |> team_of()
      team_on_v3 = new_user() |> subscribe_to_plan(@v3_plan_id) |> team_of()

      assert [Goals, Props, StatsAPI] == Plausible.Teams.Billing.allowed_features_for(team_on_v1)
      assert [Goals, Props, StatsAPI] == Plausible.Teams.Billing.allowed_features_for(team_on_v2)
      assert [Goals, Props, StatsAPI] == Plausible.Teams.Billing.allowed_features_for(team_on_v3)
    end

    test "returns [Goals, Props, StatsAPI] when user is on free_10k plan" do
      user = new_user()
      subscribe_to_plan(user, "free_10k")
      team = team_of(user)
      assert [Goals, Props, StatsAPI] == Plausible.Teams.Billing.allowed_features_for(team)
    end

    on_ee do
      test "returns the enterprise plan features" do
        user = new_user()

        subscribe_to_enterprise_plan(user,
          monthly_pageview_limit: 100_000,
          site_limit: 500,
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels]
        )

        team = team_of(user)

        assert [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels] ==
                 Plausible.Teams.Billing.allowed_features_for(team)
      end
    end

    test "returns all features when user in on trial" do
      team = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: 7)) |> team_of()

      assert Plausible.Billing.Feature.list() -- [Plausible.Billing.Feature.SitesAPI] ==
               Plausible.Teams.Billing.allowed_features_for(team)
    end

    test "returns previous plan limits for enterprise users who have not paid yet" do
      user =
        new_user()
        |> subscribe_to_plan(@v1_plan_id)
        |> subscribe_to_enterprise_plan(subscription?: false)

      team = team_of(user)

      assert [Goals, Props, StatsAPI] == Plausible.Teams.Billing.allowed_features_for(team)
    end

    test "returns all features for enterprise users who have not upgraded yet and are on trial" do
      team = new_user() |> subscribe_to_enterprise_plan(subscription?: false) |> team_of()

      assert Plausible.Billing.Feature.list() -- [Plausible.Billing.Feature.SitesAPI] ==
               Plausible.Teams.Billing.allowed_features_for(team)
    end

    test "returns old plan features for enterprise customers who are due to change a plan" do
      user = new_user()

      subscribe_to_enterprise_plan(user,
        paddle_plan_id: "old-paddle-plan-id",
        features: [Plausible.Billing.Feature.StatsAPI]
      )

      subscribe_to_enterprise_plan(user,
        paddle_plan_id: "new-paddle-plan-id",
        subscription?: false
      )

      team = team_of(user)

      assert [Plausible.Billing.Feature.StatsAPI] ==
               Plausible.Teams.Billing.allowed_features_for(team)
    end

    test "returns SitesAPI feature for enterprise customers with appropriate plan" do
      user = new_user()

      subscribe_to_enterprise_plan(user,
        features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
      )

      team = team_of(user)

      assert [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI] ==
               Plausible.Teams.Billing.allowed_features_for(team)
    end
  end

  describe "monthly_pageview_usage/2" do
    test "returns empty usage for user without subscription and without any sites" do
      team = new_user() |> team_of()

      assert %{
               last_30_days: %{
                 total: 0,
                 custom_events: 0,
                 pageviews: 0,
                 date_range: date_range
               }
             } = Plausible.Teams.Billing.monthly_pageview_usage(team)

      assert date_range.last == Date.utc_today()
      assert Date.compare(date_range.first, date_range.last) == :lt
    end

    test "returns usage for user without subscription with a site" do
      user = new_user()
      site = new_site(owner: user)
      team = team_of(user)

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
             } = Plausible.Teams.Billing.monthly_pageview_usage(team)
    end

    test "engagement events are not counted towards monthly pageview usage" do
      user = new_user()
      site = new_site(owner: user)
      team = team_of(user)
      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:event, timestamp: Timex.shift(now, days: -8), name: "custom"),
        build(:pageview, user_id: 199, timestamp: Timex.shift(now, days: -5, minutes: -2)),
        build(:engagement, user_id: 199, timestamp: Timex.shift(now, days: -5))
      ])

      assert %{
               last_30_days: %{
                 total: 2,
                 custom_events: 1,
                 pageviews: 1,
                 date_range: %{}
               }
             } = Plausible.Teams.Billing.monthly_pageview_usage(team)
    end

    test "returns usage for user with subscription and a site" do
      today = Date.utc_today()
      user = new_user()
      subscribe_to_growth_plan(user, last_bill_date: Date.shift(today, day: -8))
      team = team_of(user)

      site = new_site(owner: user)

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
             } = Plausible.Teams.Billing.monthly_pageview_usage(team)
    end

    test "returns usage for only a subset of site IDs" do
      today = Date.utc_today()

      user = new_user()
      subscribe_to_growth_plan(user, last_bill_date: Date.shift(today, day: -8))
      team = team_of(user)

      site1 = new_site(owner: user)
      site2 = new_site(owner: user)
      site3 = new_site(owner: user)

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
             } = Plausible.Teams.Billing.monthly_pageview_usage(team, [site1.id, site3.id])
    end
  end

  describe "usage_cycle/1" do
    setup do
      user = new_user()
      site = new_site(owner: user)
      team = team_of(user)

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

      {:ok, %{user: user, team: team}}
    end

    test "returns usage and date_range for the given billing month", %{user: user, team: team} do
      last_bill_date = ~D[2023-06-03]
      today = ~D[2023-06-05]

      subscribe_to_growth_plan(user, last_bill_date: last_bill_date)

      assert %{date_range: penultimate_cycle, pageviews: 2, custom_events: 3, total: 5} =
               Plausible.Teams.Billing.usage_cycle(team, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle, pageviews: 3, custom_events: 2, total: 5} =
               Plausible.Teams.Billing.usage_cycle(team, :last_cycle, nil, today)

      assert %{date_range: current_cycle, pageviews: 0, custom_events: 3, total: 3} =
               Plausible.Teams.Billing.usage_cycle(team, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2023-04-03], ~D[2023-05-02])
      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
      assert current_cycle == Date.range(~D[2023-06-03], ~D[2023-07-02])
    end

    test "returns usage and date_range for the last 30 days", %{team: team} do
      today = ~D[2023-06-01]

      assert %{date_range: last_30_days, pageviews: 4, custom_events: 1, total: 5} =
               Plausible.Teams.Billing.usage_cycle(team, :last_30_days, nil, today)

      assert last_30_days == Date.range(~D[2023-05-02], ~D[2023-06-01])
    end

    test "only considers sites that the user owns", %{user: user, team: team} do
      different_site = new_site()
      add_guest(different_site, user: user, role: :editor)

      populate_stats(different_site, [
        build(:event, timestamp: ~N[2023-05-05 00:00:00], name: "custom")
      ])

      last_bill_date = ~D[2023-06-03]
      today = ~D[2023-06-05]

      subscribe_to_growth_plan(user, last_bill_date: last_bill_date)

      assert %{date_range: last_cycle, pageviews: 3, custom_events: 2, total: 5} =
               Plausible.Teams.Billing.usage_cycle(team, :last_cycle, nil, today)

      assert last_cycle == Date.range(~D[2023-05-03], ~D[2023-06-02])
    end

    test "in case of yearly billing, cycles are normalized as if they were paying monthly" do
      last_bill_date = ~D[2020-09-01]
      today = ~D[2021-02-02]

      user = new_user()
      subscribe_to_growth_plan(user, last_bill_date: last_bill_date)
      team = team_of(user)

      assert %{date_range: penultimate_cycle} =
               Plausible.Teams.Billing.usage_cycle(team, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle} =
               Plausible.Teams.Billing.usage_cycle(team, :last_cycle, nil, today)

      assert %{date_range: current_cycle} =
               Plausible.Teams.Billing.usage_cycle(team, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert last_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
      assert current_cycle == Date.range(~D[2021-02-01], ~D[2021-02-28])
    end

    test "returns correct billing months when last_bill_date is the first day of the year" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]

      user = new_user()
      subscribe_to_growth_plan(user, last_bill_date: last_bill_date)
      team = team_of(user)

      assert %{date_range: penultimate_cycle, total: 0} =
               Plausible.Teams.Billing.usage_cycle(team, :penultimate_cycle, nil, today)

      assert %{date_range: last_cycle, total: 0} =
               Plausible.Teams.Billing.usage_cycle(team, :last_cycle, nil, today)

      assert %{date_range: current_cycle, total: 0} =
               Plausible.Teams.Billing.usage_cycle(team, :current_cycle, nil, today)

      assert penultimate_cycle == Date.range(~D[2020-11-01], ~D[2020-11-30])
      assert last_cycle == Date.range(~D[2020-12-01], ~D[2020-12-31])
      assert current_cycle == Date.range(~D[2021-01-01], ~D[2021-01-31])
    end
  end

  describe "suggest_tier/2" do
    setup do
      user = new_user()
      team = user |> team_of() |> Plausible.Teams.with_subscription()
      %{user: user, team: team}
    end

    test "returns nil if usage doesn't have any sites", %{team: team} do
      suggested_tier =
        team
        |> Plausible.Teams.Billing.quota_usage(with_features: true)
        |> Quota.suggest_tier(@highest_growth_plan, @highest_business_plan, nil)

      assert suggested_tier == nil
    end

    test "returns :custom if the monthly pageview limit exceeds regular plans",
         %{team: team} do
      suggested_tier =
        team
        |> Plausible.Teams.Billing.quota_usage(with_features: true)
        |> Map.merge(%{monthly_pageviews: %{last_30_days: %{total: 12_000_000}}, sites: 1})
        |> Quota.suggest_tier(@highest_growth_plan, @highest_business_plan, nil)

      assert suggested_tier == :custom
    end

    test "returns :growth if usage within growth limits",
         %{team: team} do
      suggested_tier =
        team
        |> Plausible.Teams.Billing.quota_usage(with_features: true)
        |> Map.put(:sites, 1)
        |> Quota.suggest_tier(@highest_growth_plan, @highest_business_plan, nil)

      assert suggested_tier == :growth
    end

    test "returns :business if usage within growth limits but already on a business plan",
         %{team: team} do
      suggested_tier =
        team
        |> Plausible.Teams.Billing.quota_usage(with_features: true)
        |> Map.put(:sites, 1)
        |> Quota.suggest_tier(@highest_growth_plan, @highest_business_plan, :business)

      assert suggested_tier == :business
    end

    test "returns :business if business features used",
         %{team: team} do
      suggested_tier =
        team
        |> Plausible.Teams.Billing.quota_usage(with_features: true)
        |> Map.merge(%{sites: 1, features: [Plausible.Billing.Feature.Funnels]})
        |> Quota.suggest_tier(@highest_growth_plan, @highest_business_plan, nil)

      assert suggested_tier == :business
    end
  end
end
