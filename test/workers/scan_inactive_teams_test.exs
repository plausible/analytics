defmodule Plausible.Workers.ScanInactiveTeamsTest do
  use Plausible.DataCase, async: true

  alias Plausible.TeamDeletionSchedule
  alias Plausible.Workers.ScanInactiveTeams

  test "schedules a team whose trial has expired" do
    team = insert(:team, trial_expiry_date: Date.shift(Date.utc_today(), day: -1))

    ScanInactiveTeams.perform(nil)

    schedule = Repo.get_by!(TeamDeletionSchedule, team_id: team.id)
    assert schedule.category == :expired_trial
    assert schedule.status == :scheduled
  end

  test "does not schedule a team still on an active trial" do
    insert(:team, trial_expiry_date: Date.shift(Date.utc_today(), day: 1))

    ScanInactiveTeams.perform(nil)

    assert Repo.aggregate(TeamDeletionSchedule, :count) == 0
  end

  test "is idempotent across repeated runs" do
    insert(:team, trial_expiry_date: Date.shift(Date.utc_today(), day: -1))

    ScanInactiveTeams.perform(nil)
    ScanInactiveTeams.perform(nil)

    assert Repo.aggregate(TeamDeletionSchedule, :count) == 1
  end

  test "emits telemetry with the number of newly-scheduled teams", %{test: test} do
    test_pid = self()
    telemetry_run = ScanInactiveTeams.telemetry_run_event()

    :telemetry.attach(
      "#{test}-telemetry-handler",
      telemetry_run,
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_handled, event, measurements, metadata})
      end,
      %{}
    )

    insert(:team, trial_expiry_date: Date.shift(Date.utc_today(), day: -1))

    ScanInactiveTeams.perform(nil)

    assert_receive {:telemetry_handled, ^telemetry_run, %{created: 1}, %{}}
  end
end
