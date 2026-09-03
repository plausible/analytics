defmodule Plausible.Workers.UnsnoozeTeamDeletionsTest do
  use Plausible.DataCase, async: true

  on_ee do
    alias Plausible.Workers.UnsnoozeTeamDeletions

    @today ~D[2026-08-20]

    test "restarts the notice cycle for a schedule whose snooze has lapsed" do
      schedule =
        insert(:team_deletion_schedule,
          status: :snoozed,
          is_backlog: false,
          snoozed_until: @today,
          snooze_note: "customer asked for time",
          first_notice_sent_at: ~N[2026-07-01 10:00:00],
          reminder_sent_at: ~N[2026-07-20 10:00:00]
        )

      assert :ok = UnsnoozeTeamDeletions.perform(nil, @today)

      updated = Repo.reload!(schedule)
      assert updated.status == :scheduled
      assert updated.is_backlog
      assert updated.first_notice_due_date == @today
      assert updated.first_notice_sent_at == nil
      assert updated.reminder_sent_at == nil
      assert updated.snoozed_until == nil
      assert updated.snooze_note == nil
    end

    test "restarts a schedule whose snooze is overdue (missed run catch-up)" do
      schedule =
        insert(:team_deletion_schedule,
          status: :snoozed,
          snoozed_until: Date.shift(@today, day: -3)
        )

      assert :ok = UnsnoozeTeamDeletions.perform(nil, @today)

      assert Repo.reload!(schedule).status == :scheduled
    end

    test "does not touch a row whose snooze hasn't lapsed yet" do
      schedule =
        insert(:team_deletion_schedule,
          status: :snoozed,
          snoozed_until: Date.shift(@today, day: 1)
        )

      assert :ok = UnsnoozeTeamDeletions.perform(nil, @today)

      updated = Repo.reload!(schedule)
      assert updated.status == :snoozed
      assert updated.snoozed_until == Date.shift(@today, day: 1)
    end

    test "does not touch a row that isn't snoozed" do
      schedule = insert(:team_deletion_schedule, status: :reminder_sent, deletion_date: @today)

      assert :ok = UnsnoozeTeamDeletions.perform(nil, @today)

      assert Repo.reload!(schedule).status == :reminder_sent
    end
  end
end
