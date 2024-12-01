defmodule Plausible.Workers.LockSitesTest do
  use Plausible.DataCase, async: true
  require Plausible.Billing.Subscription.Status
  alias Plausible.Workers.LockSites
  alias Plausible.Billing.Subscription

  test "does not lock enterprise site on grace period" do
    user =
      :user
      |> build()
      |> Plausible.Auth.GracePeriod.start_manual_lock_changeset()
      |> Plausible.Repo.insert!()

    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock trial user's site" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "locks site for user whose trial has expired" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))
    site = insert(:site, members: [user])

    LockSites.perform(nil)

    assert Repo.reload!(site).locked
  end

  test "does not lock active subscriber's sites" do
    user = insert(:user)
    insert(:subscription, status: Subscription.Status.active(), user: user)
    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock user who is past due" do
    user = insert(:user)
    insert(:subscription, status: Subscription.Status.past_due(), user: user)
    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock user who cancelled subscription but it hasn't expired yet" do
    user = insert(:user)
    insert(:subscription, status: Subscription.Status.deleted(), user: user)
    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "locks user who cancelled subscription and the cancelled subscription has expired" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))

    insert(:subscription,
      status: Subscription.Status.deleted(),
      next_bill_date: Timex.today() |> Timex.shift(days: -1),
      user: user
    )

    site = insert(:site, members: [user])

    LockSites.perform(nil)

    assert Repo.reload!(site).locked
  end

  test "does not lock if user has an old cancelled subscription and a new active subscription" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))

    insert(:subscription,
      status: Subscription.Status.deleted(),
      next_bill_date: Timex.today() |> Timex.shift(days: -1),
      user: user,
      inserted_at: Timex.now() |> Timex.shift(days: -1)
    )

    insert(:subscription, status: Subscription.Status.active(), user: user)

    site = insert(:site, members: [user])

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  describe "locking" do
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

      LockSites.perform(nil)

      owner_site = Repo.reload!(owner_site)
      viewer_site = Repo.reload!(viewer_site)

      assert owner_site.locked
      refute viewer_site.locked
    end
  end
end
