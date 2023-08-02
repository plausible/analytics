defmodule Plausible.Billing.SiteLockerTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  alias Plausible.Billing.SiteLocker

  describe "check_sites_for/1" do
    test "does not lock sites if user is on trial" do
      user = insert(:user, trial_expiry_date: Timex.today())

      site = insert(:site, locked: true, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "does not lock if user has an active subscription" do
      user = insert(:user)
      insert(:subscription, status: "active", user: user)
      site = insert(:site, locked: true, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "does not lock user who is past due" do
      user = insert(:user)
      insert(:subscription, status: "past_due", user: user)
      site = insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "does not lock user who cancelled subscription but it hasn't expired yet" do
      user = insert(:user)
      insert(:subscription, status: "deleted", user: user)
      site = insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "does not lock user who has an active subscription and is on grace period" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: 1),
            allowance_required: 10_000
          }
        )

      insert(:subscription, status: "active", user: user)
      site = insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "locks user who cancelled subscription and the cancelled subscription has expired" do
      user = insert(:user)

      insert(:subscription,
        status: "deleted",
        next_bill_date: Timex.today() |> Timex.shift(days: -1),
        user: user
      )

      site = insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      refute Repo.reload!(site).locked
    end

    test "locks all sites if user has active subscription but grace period has ended" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: -1),
            allowance_required: 10_000
          }
        )

      insert(:subscription, status: "active", user: user)
      site = insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      assert Repo.reload!(site).locked
    end

    test "sends email if grace period has ended" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: -1),
            allowance_required: 10_000
          }
        )

      insert(:subscription, status: "active", user: user)
      insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )
    end

    test "does not send grace period email if site is already locked" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: -1),
            allowance_required: 10_000,
            is_over: false
          }
        )

      insert(:subscription, status: "active", user: user)
      insert(:site, members: [user])

      SiteLocker.check_sites_for(user)

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] Your Plausible dashboard is now locked"
      )

      user = Repo.reload!(user)
      SiteLocker.check_sites_for(user)

      assert_no_emails_delivered()
    end

    test "locks all sites if user has no trial or active subscription" do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))

      site = insert(:site, locked: true, members: [user])

      SiteLocker.check_sites_for(user)

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

      SiteLocker.check_sites_for(user)

      owner_site = Repo.reload!(owner_site)
      viewer_site = Repo.reload!(viewer_site)

      assert owner_site.locked
      refute viewer_site.locked
    end
  end
end
