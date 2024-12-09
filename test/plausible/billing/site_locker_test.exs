defmodule Plausible.Billing.SiteLockerTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  use Plausible.Teams.Test
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{SiteLocker, Subscription}

  describe "update_sites_for/1" do
    test "does not lock sites if user is on trial" do
      user = new_user(trial_expiry_date: Date.utc_today())
      site = new_site(owner: user, locked: true)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock if user has an active subscription" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who is past due" do
      user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.past_due())
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who cancelled subscription but it hasn't expired yet" do
      user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.deleted())
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who has an active subscription and is on grace period" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: 1)}

      user =
        new_user(team: [grace_period: grace_period])
        |> subscribe_to_growth_plan()

      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == :unlocked

      refute Repo.reload!(site).locked
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

      assert SiteLocker.update_sites_for(team) == {:locked, :no_active_subscription}

      assert Repo.reload!(site).locked
    end

    test "locks all sites if user has active subscription but grace period has ended" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(team: [grace_period: grace_period])
      subscribe_to_plan(user, "123")
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == {:locked, :grace_period_ended_now}

      assert Repo.reload!(site).locked
    end

    test "sends email if grace period has ended" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(team: [grace_period: grace_period])
      subscribe_to_plan(user, "123")
      new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == {:locked, :grace_period_ended_now}

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )
    end

    test "does not send grace period email if site is already locked" do
      grace_period = %Plausible.Auth.GracePeriod{
        end_date: Timex.shift(Timex.today(), days: -1),
        is_over: false
      }

      user = new_user(team: [grace_period: grace_period])

      subscribe_to_plan(user, "123")
      new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == {:locked, :grace_period_ended_now}

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      team = Repo.reload!(team)
      assert SiteLocker.update_sites_for(team) == {:locked, :grace_period_ended_already}

      assert_no_emails_delivered()
    end

    test "locks all sites if user has no trial or active subscription" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      site = new_site(owner: user)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == {:locked, :no_active_subscription}

      assert Repo.reload!(site).locked
    end

    test "locks sites for user with empty trial - shouldn't happen under normal circumstances" do
      user = new_user()
      site = new_site(owner: user)
      team = user |> team_of() |> Ecto.Changeset.change(trial_expiry_date: nil) |> Repo.update!()

      assert SiteLocker.update_sites_for(team) == {:locked, :no_trial}

      assert Repo.reload!(site).locked
    end

    test "only locks sites that the user owns" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))

      owner_site = new_site(owner: user)
      viewer_site = new_site()
      add_guest(viewer_site, user: user, role: :viewer)
      team = team_of(user)

      assert SiteLocker.update_sites_for(team) == {:locked, :no_active_subscription}

      owner_site = Repo.reload!(owner_site)
      viewer_site = Repo.reload!(viewer_site)

      assert owner_site.locked
      refute viewer_site.locked
    end
  end
end
