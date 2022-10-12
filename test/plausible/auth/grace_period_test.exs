defmodule Plausible.Auth.GracePeriodTest do
  use Plausible.DataCase, async: true

  test "active?/1 returns false when grace period cannot be telled" do
    without_grace_period = build(:user, grace_period: nil)
    refute Plausible.Auth.GracePeriod.active?(without_grace_period)

    without_user = nil
    refute Plausible.Auth.GracePeriod.active?(without_user)
  end

  test "active?/1 returns false when grace period is expired" do
    yesterday = Date.add(Date.utc_today(), -1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: yesterday,
      allowance_required: 100,
      is_over: false
    }

    user = build(:user, grace_period: grace_period)

    refute Plausible.Auth.GracePeriod.active?(user)
  end

  test "active?/1 returns true when grace period is still active" do
    tomorrow = Date.add(Date.utc_today(), 1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: tomorrow,
      allowance_required: 100,
      is_over: false
    }

    user = build(:user, grace_period: grace_period)

    assert Plausible.Auth.GracePeriod.active?(user)
  end

  test "expired?/1 returns false when grace period cannot be telled" do
    without_grace_period = build(:user, grace_period: nil)
    refute Plausible.Auth.GracePeriod.expired?(without_grace_period)

    without_user = nil
    refute Plausible.Auth.GracePeriod.expired?(without_user)
  end

  test "expired?/1 returns true when grace period is expired" do
    yesterday = Date.add(Date.utc_today(), -1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: yesterday,
      allowance_required: 100,
      is_over: true
    }

    user = build(:user, grace_period: grace_period)

    assert Plausible.Auth.GracePeriod.expired?(user)
  end

  test "expired?/1 returns false when grace period is still active" do
    tomorrow = Date.add(Date.utc_today(), 1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: tomorrow,
      allowance_required: 100,
      is_over: false
    }

    user = build(:user, grace_period: grace_period)

    refute Plausible.Auth.GracePeriod.expired?(user)
  end

  test "start_manual_lock_changeset/1 creates an active grace period" do
    user = build(:user)
    changeset = Plausible.Auth.GracePeriod.start_manual_lock_changeset(user, 1)
    user = Ecto.Changeset.apply_changes(changeset)

    assert Plausible.Auth.GracePeriod.active?(user)
    refute Plausible.Auth.GracePeriod.expired?(user)
  end

  test "start_changeset/1 creates an active grace period" do
    user = build(:user)
    changeset = Plausible.Auth.GracePeriod.start_changeset(user, 1)
    user = Ecto.Changeset.apply_changes(changeset)

    assert Plausible.Auth.GracePeriod.active?(user)
    refute Plausible.Auth.GracePeriod.expired?(user)
  end

  test "remove_changeset/1 removes the active grace period" do
    user = build(:user)
    start_changeset = Plausible.Auth.GracePeriod.start_changeset(user, 1)
    user = Ecto.Changeset.apply_changes(start_changeset)

    remove_changeset = Plausible.Auth.GracePeriod.remove_changeset(user)
    user = Ecto.Changeset.apply_changes(remove_changeset)

    refute Plausible.Auth.GracePeriod.active?(user)
    refute Plausible.Auth.GracePeriod.expired?(user)
  end
end
