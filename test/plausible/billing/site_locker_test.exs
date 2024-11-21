defmodule Plausible.Billing.SiteLockerTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  use Plausible.Teams.Test
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{SiteLocker, Subscription}

  describe "update_sites_for/1" do
    test "does not lock sites if user is on trial" do
      user = insert(:user, trial_expiry_date: Timex.today())

      site =
        insert(:site,
          locked: true,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock if user has an active subscription" do
      user = insert(:user)
      insert(:subscription, status: Subscription.Status.active(), user: user)

      site =
        insert(:site,
          locked: true,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who is past due" do
      user = insert(:user)
      insert(:subscription, status: Subscription.Status.past_due(), user: user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who cancelled subscription but it hasn't expired yet" do
      user = insert(:user)
      insert(:subscription, status: Subscription.Status.deleted(), user: user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "does not lock user who has an active subscription and is on grace period" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: 1)}
      user = insert(:user, grace_period: grace_period)

      insert(:subscription, status: Subscription.Status.active(), user: user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == :unlocked

      refute Repo.reload!(site).locked
    end

    test "locks user who cancelled subscription and the cancelled subscription has expired" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      insert(:subscription,
        status: Subscription.Status.deleted(),
        next_bill_date: Timex.today() |> Timex.shift(days: -1),
        user: user
      )

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == {:locked, :no_active_subscription}

      assert Repo.reload!(site).locked
    end

    test "locks all sites if user has active subscription but grace period has ended" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(grace_period: grace_period)
      subscribe_to_plan(user, "123")
      site = new_site(owner: user)

      assert SiteLocker.update_sites_for(user) == {:locked, :grace_period_ended_now}

      assert Repo.reload!(site).locked
    end

    @tag :teams
    test "syncs grace period end with teams" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(grace_period: grace_period)
      subscribe_to_plan(user, "123")
      new_site(owner: user)

      assert SiteLocker.update_sites_for(user) == {:locked, :grace_period_ended_now}

      assert user = Repo.reload!(user)
      team = assert_team_exists(user)
      assert user.grace_period.is_over
      assert team.grace_period.is_over
    end

    test "sends email if grace period has ended" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(grace_period: grace_period)
      subscribe_to_plan(user, "123")
      new_site(owner: user)

      assert SiteLocker.update_sites_for(user) == {:locked, :grace_period_ended_now}

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

      user = new_user(grace_period: grace_period)
      subscribe_to_plan(user, "123")
      new_site(owner: user)

      assert SiteLocker.update_sites_for(user) == {:locked, :grace_period_ended_now}

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      user = Repo.reload!(user)
      assert SiteLocker.update_sites_for(user) == {:locked, :grace_period_ended_already}

      assert_no_emails_delivered()
    end

    test "locks all sites if user has no trial or active subscription" do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == {:locked, :no_active_subscription}

      assert Repo.reload!(site).locked
    end

    test "locks sites for user with empty trial - shouldn't happen under normal circumstances" do
      user = insert(:user, trial_expiry_date: nil)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      assert SiteLocker.update_sites_for(user) == {:locked, :no_trial}

      assert Repo.reload!(site).locked
    end

    test "only locks sites that the user owns" do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))

      owner_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      viewer_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :viewer)
          ]
        )

      assert SiteLocker.update_sites_for(user) == {:locked, :no_active_subscription}

      owner_site = Repo.reload!(owner_site)
      viewer_site = Repo.reload!(viewer_site)

      assert owner_site.locked
      refute viewer_site.locked
    end
  end
end
