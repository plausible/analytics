defmodule Plausible.Workers.LockSitesTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  require Plausible.Billing.Subscription.Status
  alias Plausible.Workers.LockSites
  alias Plausible.Billing.Subscription

  @moduletag :ee_only

  test "does not lock enterprise site on grace period" do
    user = new_user()
    site = new_site(owner: user)

    user
    |> team_of()
    |> Plausible.Teams.start_manual_lock_grace_period()

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock trial user's site" do
    user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 1))
    site = new_site(owner: user)

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "locks site for user whose trial has expired" do
    user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
    site = new_site(owner: user)

    LockSites.perform(nil)

    assert Repo.reload!(site).locked
  end

  test "does not lock active subsriber's sites" do
    user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.active())
    site = new_site(owner: user)

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock user who is past due" do
    user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.past_due())
    site = new_site(owner: user)

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "does not lock user who cancelled subscription but it hasn't expired yet" do
    user = new_user() |> subscribe_to_growth_plan(status: Subscription.Status.deleted())
    site = new_site(owner: user)

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  test "locks user who cancelled subscription and the cancelled subscription has expired" do
    user =
      new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      |> subscribe_to_growth_plan(
        status: Subscription.Status.deleted(),
        next_bill_date: Date.utc_today() |> Date.shift(day: -1)
      )

    site = new_site(owner: user)

    LockSites.perform(nil)

    assert Repo.reload!(site).locked
  end

  test "does not lock if user has an old cancelled subscription and a new active subscription" do
    user =
      new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      |> subscribe_to_growth_plan(
        status: Subscription.Status.deleted(),
        next_bill_date: Date.utc_today() |> Date.shift(day: -1),
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
      )
      |> subscribe_to_growth_plan(status: Subscription.Status.deleted())

    site = new_site(owner: user)

    LockSites.perform(nil)

    refute Repo.reload!(site).locked
  end

  describe "locking" do
    test "only locks sites that the user owns" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))

      owner_site = new_site(owner: user)
      viewer_site = new_site()
      add_guest(viewer_site, user: user, role: :viewer)

      LockSites.perform(nil)

      owner_site = Repo.reload!(owner_site)
      viewer_site = Repo.reload!(viewer_site)

      assert owner_site.locked
      refute viewer_site.locked
    end
  end
end
