defmodule Plausible.Auth.GracePeriodTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  test "active?/1 returns false when grace period cannot be telled" do
    without_grace_period =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: nil])
      |> team_of()

    refute Plausible.Auth.GracePeriod.active?(without_grace_period)

    without_team = nil
    refute Plausible.Auth.GracePeriod.active?(without_team)
  end

  test "active?/1 returns false when grace period is expired" do
    yesterday = Date.add(Date.utc_today(), -1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: yesterday,
      is_over: false
    }

    team =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: grace_period])
      |> team_of()

    refute Plausible.Auth.GracePeriod.active?(team)
  end

  test "active?/1 returns true when grace period is still active" do
    tomorrow = Date.add(Date.utc_today(), 1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: tomorrow,
      is_over: false
    }

    team =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: grace_period])
      |> team_of()

    assert Plausible.Auth.GracePeriod.active?(team)
  end

  test "expired?/1 returns false when grace period cannot be telled" do
    without_grace_period =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: nil])
      |> team_of()

    refute Plausible.Auth.GracePeriod.expired?(without_grace_period)

    without_team = nil
    refute Plausible.Auth.GracePeriod.expired?(without_team)
  end

  test "expired?/1 returns true when grace period is expired" do
    yesterday = Date.add(Date.utc_today(), -1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: yesterday,
      is_over: true
    }

    team =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: grace_period])
      |> team_of()

    assert Plausible.Auth.GracePeriod.expired?(team)
  end

  test "expired?/1 returns false when grace period is still active" do
    tomorrow = Date.add(Date.utc_today(), 1)

    grace_period = %Plausible.Auth.GracePeriod{
      end_date: tomorrow,
      is_over: false
    }

    team =
      new_user(trial_expiry_date: Date.utc_today(), team: [grace_period: grace_period])
      |> team_of()

    refute Plausible.Auth.GracePeriod.expired?(team)
  end

  test "start_manual_lock_changeset/1 creates an active grace period" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    changeset = Plausible.Auth.GracePeriod.start_manual_lock_changeset(team)
    team = Ecto.Changeset.apply_changes(changeset)

    assert Plausible.Auth.GracePeriod.active?(team)
    refute Plausible.Auth.GracePeriod.expired?(team)
  end

  test "start_changeset/1 creates an active grace period" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    changeset = Plausible.Auth.GracePeriod.start_changeset(team)
    team = Ecto.Changeset.apply_changes(changeset)

    assert Plausible.Auth.GracePeriod.active?(team)
    refute Plausible.Auth.GracePeriod.expired?(team)
  end

  test "remove_changeset/1 removes the active grace period" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    start_changeset = Plausible.Auth.GracePeriod.start_changeset(team)
    team = Ecto.Changeset.apply_changes(start_changeset)

    remove_changeset = Plausible.Auth.GracePeriod.remove_changeset(team)
    team = Ecto.Changeset.apply_changes(remove_changeset)

    refute Plausible.Auth.GracePeriod.active?(team)
    refute Plausible.Auth.GracePeriod.expired?(team)
  end
end
