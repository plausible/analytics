defmodule Plausible.Billing.SiteLockerTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  use Plausible.Teams.Test
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{SiteLocker, Subscription}

  @moduletag :ee_only

  @v4_growth_plan_id "857097"

  describe "update_for/1" do
    test "does not lock sites if user is on trial" do
      user = new_user(trial_expiry_date: Date.utc_today())
      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "does not lock if user has an active subscription" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "does not lock user who is past due" do
      user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.past_due())
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "does not lock user who cancelled subscription but it hasn't expired yet" do
      user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.deleted())
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "does not lock team which has an active subscription and is on grace period" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: 1)
      }

      user =
        new_user(team: [grace_period: grace_period])
        |> subscribe_to_growth_plan()

      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "does not lock enterprise customers with (manual lock) graceperiod ended" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.utc_today() |> Date.shift(day: -1),
        manual_lock: true
      }

      user =
        new_user(team: [grace_period: grace_period])
        |> subscribe_to_enterprise_plan(monthly_pageview_limit: 10_000)

      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "locks user who cancelled subscription and the cancelled subscription has expired" do
      user =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          next_bill_date: Date.utc_today() |> Date.shift(day: -1),
          status: Subscription.Status.deleted()
        )

      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == {:locked, :no_active_trial_or_subscription}

      assert Repo.reload!(site.team).locked
    end

    test "locks all sites if team has an active subscription but grace period has ended (still over limits)" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -1)
      }

      user = new_user(team: [grace_period: grace_period])
      subscribe_to_plan(user, @v4_growth_plan_id)
      site = new_site(owner: user)
      team = team_of(user)

      over_limits_usage_stub = monthly_pageview_usage_stub(15_000, 15_000)

      assert SiteLocker.update_for(team, usage_mod: over_limits_usage_stub) ==
               {:locked, :grace_period_ended_now}

      assert Repo.reload!(site.team).locked
    end

    test "does not lock sites (and removes grace period), when on active subscription and grace period ended, but usage now within limits" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -1)
      }

      user = new_user(team: [grace_period: grace_period])
      subscribe_to_plan(user, @v4_growth_plan_id)
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked

      assert_no_emails_delivered()
    end

    test "sends email to all billing members if grace period has ended and still over limits" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -1)
      }

      user = new_user(team: [grace_period: grace_period])
      subscribe_to_plan(user, @v4_growth_plan_id)
      new_site(owner: user)
      team = team_of(user)

      billing_member = new_user()
      add_member(team, user: billing_member, role: :billing)

      over_limits_usage_stub = monthly_pageview_usage_stub(15_000, 15_000)

      assert SiteLocker.update_for(team, usage_mod: over_limits_usage_stub) ==
               {:locked, :grace_period_ended_now}

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      assert_email_delivered_with(
        to: [billing_member],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      assert Repo.reload!(team).locked
    end

    test "does not send grace period email if site is already locked" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -1),
        is_over: false
      }

      user = new_user(team: [grace_period: grace_period])

      subscribe_to_plan(user, @v4_growth_plan_id)
      new_site(owner: user)
      team = team_of(user)

      over_limits_usage_stub = monthly_pageview_usage_stub(15_000, 15_000)

      assert SiteLocker.update_for(team, usage_mod: over_limits_usage_stub) ==
               {:locked, :grace_period_ended_now}

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      team = Repo.reload!(team)

      assert team.locked

      assert SiteLocker.update_for(team, usage_mod: over_limits_usage_stub) ==
               {:locked, :grace_period_ended_already}

      assert_no_emails_delivered()

      assert Repo.reload!(team).locked
    end

    test "unlocks already ended grace periods when they still have an active subscription and went within limits again" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -7),
        is_over: true
      }

      user = new_user(team: [grace_period: grace_period])

      subscribe_to_plan(user, @v4_growth_plan_id)
      new_site(owner: user)
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "locks all sites if user has no trial or active subscription" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_for(team) == {:locked, :no_active_trial_or_subscription}

      assert Repo.reload!(site.team).locked
    end

    test "does not lock if team has no sites" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      site = new_site(owner: user)
      team = team_of(user)

      Plausible.Site.Removal.run(site)

      team = Repo.reload!(team)

      assert SiteLocker.update_for(team) == :unlocked

      refute Repo.reload!(site.team).locked
    end

    test "locks sites for user with empty trial - shouldn't happen under normal circumstances" do
      user = new_user()
      site = new_site(owner: user)
      team = user |> team_of() |> Ecto.Changeset.change(trial_expiry_date: nil) |> Repo.update!()

      assert SiteLocker.update_for(team) == {:locked, :no_active_trial_or_subscription}

      assert Repo.reload!(site.team).locked
    end

    test "only locks sites that the user owns" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))

      owner_site = new_site(owner: user)
      viewer_site = new_site()
      add_guest(viewer_site, user: user, role: :viewer)
      team = team_of(user)

      assert SiteLocker.update_for(team) == {:locked, :no_active_trial_or_subscription}

      assert Repo.reload!(owner_site.team).locked
      refute Repo.reload!(viewer_site.team).locked
    end
  end
end
