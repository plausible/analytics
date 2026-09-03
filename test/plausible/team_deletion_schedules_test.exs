defmodule Plausible.TeamDeletionSchedulesTest do
  use Plausible.DataCase, async: true

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.Subscription
  alias Plausible.TeamDeletionSchedule
  alias Plausible.TeamDeletionSchedules

  @today ~D[2026-08-20]

  describe "sync_eligible/1 - expired trials" do
    test "schedules a team whose trial expired with no subscription" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      new_site(team: team)

      assert TeamDeletionSchedules.sync_eligible(@today) == 1

      schedule = Repo.get_by!(TeamDeletionSchedule, team_id: team.id)
      assert schedule.category == :expired_trial
      assert schedule.expiry_date == team.trial_expiry_date
      assert schedule.deletion_date == Date.shift(team.trial_expiry_date, day: 60)
      assert schedule.status == :scheduled
    end

    test "does not schedule a team whose trial has not expired yet" do
      insert(:team, trial_expiry_date: Date.shift(@today, day: 1))

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
      assert Repo.aggregate(TeamDeletionSchedule, :count) == 0
    end

    test "does not schedule a team whose trial expires today" do
      insert(:team, trial_expiry_date: @today)

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "marks a long-expired trial as backlog, due today" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -400))
      new_site(team: team)

      assert TeamDeletionSchedules.sync_eligible(@today) == 1

      schedule = Repo.get_by!(TeamDeletionSchedule, team_id: team.id)
      assert schedule.is_backlog
      assert schedule.first_notice_due_date == @today
    end

    test "does not mark a recently-expired trial as backlog" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      new_site(team: team)

      assert TeamDeletionSchedules.sync_eligible(@today) == 1

      schedule = Repo.get_by!(TeamDeletionSchedule, team_id: team.id)
      refute schedule.is_backlog
      assert schedule.first_notice_due_date == Date.shift(team.trial_expiry_date, day: 30)
    end

    test "does not schedule a team with an expired trial but no sites" do
      insert(:team, trial_expiry_date: Date.shift(@today, day: -1))

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end
  end

  describe "sync_eligible/1 - churned subscriptions" do
    test "schedules a team with a deleted subscription past its paid period" do
      team = insert(:team)
      new_site(team: team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(@today, day: -1)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 1

      schedule = Repo.get_by!(TeamDeletionSchedule, team_id: team.id)
      assert schedule.category == :churned_subscription
      assert schedule.deletion_date == Date.shift(schedule.expiry_date, day: 180)
    end

    test "schedules a team with a paused subscription past its paid period" do
      team = insert(:team)
      new_site(team: team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.paused(),
        next_bill_date: Date.shift(@today, day: -1)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 1

      assert Repo.get_by(TeamDeletionSchedule,
               team_id: team.id,
               category: :churned_subscription
             )
    end

    test "does not schedule a churned subscription team with no sites" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(@today, day: -1)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "does not schedule a subscription whose paid period ends today" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: @today
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "does not schedule a team whose deleted subscription hasn't lapsed yet" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(@today, day: 1)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "does not schedule a team with an active subscription" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.active(),
        next_bill_date: Date.shift(@today, day: 30)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "does not schedule a team with a past_due subscription" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.past_due(),
        next_bill_date: Date.shift(@today, day: -10)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "never schedules a free_10k plan even if marked deleted" do
      team = insert(:team)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        paddle_plan_id: "free_10k",
        next_bill_date: Date.shift(@today, day: -400)
      )

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end
  end

  describe "sync_eligible/1 - permanent exclusions" do
    test "excludes enterprise teams even with an expired trial" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      insert(:enterprise_plan, team: team)

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end
  end

  describe "sync_eligible/1 - idempotency" do
    test "does not create a duplicate schedule on a second run" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      new_site(team: team)

      assert TeamDeletionSchedules.sync_eligible(@today) == 1
      assert TeamDeletionSchedules.sync_eligible(@today) == 0

      assert Repo.aggregate(TeamDeletionSchedule, :count) == 1
    end

    test "does not schedule a team that already has an active schedule" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      insert(:team_deletion_schedule, team: team, status: :first_notice_sent)

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "does not re-schedule a completed team with no sites left to delete" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      insert(:team_deletion_schedule, team: team, status: :completed)

      assert TeamDeletionSchedules.sync_eligible(@today) == 0
    end

    test "re-schedules a completed team if it still has sites (e.g. a partial deletion retry)" do
      team = insert(:team, trial_expiry_date: Date.shift(@today, day: -1))
      new_site(team: team)
      insert(:team_deletion_schedule, team: team, status: :completed)

      assert TeamDeletionSchedules.sync_eligible(@today) == 1
    end
  end

  describe "cancel_for_team/1" do
    test "cancels an active schedule when the team has an active subscription" do
      team = insert(:team)
      schedule = insert(:team_deletion_schedule, team: team, status: :scheduled)
      insert(:subscription, team: team, status: Subscription.Status.active())

      assert TeamDeletionSchedules.cancel_for_team(team) == 1
      assert Repo.reload(schedule).status == :cancelled
    end

    test "cancels an active schedule for a deleted subscription still within its paid period" do
      team = insert(:team)
      schedule = insert(:team_deletion_schedule, team: team, status: :first_notice_sent)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(Date.utc_today(), day: 10)
      )

      assert TeamDeletionSchedules.cancel_for_team(team) == 1
      assert Repo.reload(schedule).status == :cancelled
    end

    test "does not cancel when the team has no subscription at all" do
      team = insert(:team)
      schedule = insert(:team_deletion_schedule, team: team, status: :scheduled)

      assert TeamDeletionSchedules.cancel_for_team(team) == 0
      assert Repo.reload(schedule).status == :scheduled
    end

    test "does not cancel for a paused subscription" do
      team = insert(:team)
      schedule = insert(:team_deletion_schedule, team: team, status: :scheduled)
      insert(:subscription, team: team, status: Subscription.Status.paused())

      assert TeamDeletionSchedules.cancel_for_team(team) == 0
      assert Repo.reload(schedule).status == :scheduled
    end

    test "does not cancel for a deleted subscription past its paid period" do
      team = insert(:team)
      schedule = insert(:team_deletion_schedule, team: team, status: :scheduled)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(Date.utc_today(), day: -1)
      )

      assert TeamDeletionSchedules.cancel_for_team(team) == 0
      assert Repo.reload(schedule).status == :scheduled
    end

    test "leaves an already-cancelled or already-completed schedule untouched" do
      team1 = insert(:team)
      team2 = insert(:team)
      cancelled = insert(:team_deletion_schedule, team: team1, status: :cancelled)
      completed = insert(:team_deletion_schedule, team: team2, status: :completed)

      insert(:subscription, team: team1, status: Subscription.Status.active())
      insert(:subscription, team: team2, status: Subscription.Status.active())

      assert TeamDeletionSchedules.cancel_for_team(team1) == 0
      assert TeamDeletionSchedules.cancel_for_team(team2) == 0
      assert Repo.reload(cancelled).status == :cancelled
      assert Repo.reload(completed).status == :completed
    end

    test "is a no-op for a team with no schedule at all" do
      team = insert(:team)
      insert(:subscription, team: team, status: Subscription.Status.active())

      assert TeamDeletionSchedules.cancel_for_team(team) == 0
    end
  end

  describe "transitions/0" do
    test "matches the schema's known statuses" do
      transitions = TeamDeletionSchedules.transitions()

      assert Map.keys(transitions) |> Enum.sort() == Enum.sort(TeamDeletionSchedule.statuses())

      for {_from, targets} <- transitions, target <- targets do
        assert target in TeamDeletionSchedule.statuses()
      end
    end
  end

  describe "mark_first_notice_sent/2" do
    test "sends the first notice for a steady-state schedule, keeping its deletion_date" do
      schedule =
        insert(:team_deletion_schedule,
          status: :scheduled,
          is_backlog: false,
          deletion_date: ~D[2026-10-19]
        )

      now = ~N[2026-08-20 10:00:00]

      assert {:ok, updated} = TeamDeletionSchedules.mark_first_notice_sent(schedule, now)
      assert updated.status == :first_notice_sent
      assert updated.first_notice_sent_at == now
      assert updated.deletion_date == ~D[2026-10-19]
    end

    test "sends the first notice for a backlog schedule, anchoring deletion_date to now" do
      schedule =
        insert(:team_deletion_schedule,
          status: :scheduled,
          is_backlog: true,
          deletion_date: ~D[2026-01-01]
        )

      now = ~N[2026-08-20 10:00:00]

      assert {:ok, updated} = TeamDeletionSchedules.mark_first_notice_sent(schedule, now)
      assert updated.status == :first_notice_sent
      assert updated.first_notice_sent_at == now
      assert updated.deletion_date == Plausible.Teams.DeletionSchedule.backlog_deletion_date(now)
    end

    test "rejects any status other than :scheduled" do
      for status <- TeamDeletionSchedule.statuses() -- [:scheduled] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.mark_first_notice_sent(schedule, ~N[2026-08-20 10:00:00]) ==
                 {:error, {:invalid_transition, status, :first_notice_sent}}
      end
    end
  end

  describe "mark_reminder_sent/2" do
    test "sends the reminder for a schedule that already sent its first notice" do
      schedule = insert(:team_deletion_schedule, status: :first_notice_sent)
      now = ~N[2026-08-20 10:00:00]

      assert {:ok, updated} = TeamDeletionSchedules.mark_reminder_sent(schedule, now)
      assert updated.status == :reminder_sent
      assert updated.reminder_sent_at == now
    end

    test "rejects any status other than :first_notice_sent" do
      for status <- TeamDeletionSchedule.statuses() -- [:first_notice_sent] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.mark_reminder_sent(schedule, ~N[2026-08-20 10:00:00]) ==
                 {:error, {:invalid_transition, status, :reminder_sent}}
      end
    end
  end

  describe "mark_completed/1" do
    test "completes a schedule that already sent its reminder" do
      schedule = insert(:team_deletion_schedule, status: :reminder_sent)

      assert {:ok, updated} = TeamDeletionSchedules.mark_completed(schedule)
      assert updated.status == :completed
    end

    test "rejects any status other than :reminder_sent" do
      for status <- TeamDeletionSchedule.statuses() -- [:reminder_sent] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.mark_completed(schedule) ==
                 {:error, {:invalid_transition, status, :completed}}
      end
    end
  end

  describe "cancel/1" do
    test "cancels a schedule from any active status" do
      for status <- [:scheduled, :first_notice_sent, :reminder_sent, :snoozed] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert {:ok, updated} = TeamDeletionSchedules.cancel(schedule)
        assert updated.status == :cancelled
      end
    end

    test "rejects an already-terminal status" do
      for status <- [:completed, :cancelled] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.cancel(schedule) ==
                 {:error, {:invalid_transition, status, :cancelled}}
      end
    end
  end

  describe "snooze/3" do
    test "snoozes a schedule from any active, not-yet-snoozed status" do
      for status <- [:scheduled, :first_notice_sent, :reminder_sent] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert {:ok, updated} =
                 TeamDeletionSchedules.snooze(schedule, ~D[2026-09-20], "customer asked for time")

        assert updated.status == :snoozed
        assert updated.snoozed_until == ~D[2026-09-20]
        assert updated.snooze_note == "customer asked for time"
      end
    end

    test "defaults the note to nil" do
      schedule = insert(:team_deletion_schedule, status: :scheduled)

      assert {:ok, updated} = TeamDeletionSchedules.snooze(schedule, ~D[2026-09-20])
      assert updated.snooze_note == nil
    end

    test "rejects an already-snoozed or terminal status" do
      for status <- [:snoozed, :completed, :cancelled] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.snooze(schedule, ~D[2026-09-20]) ==
                 {:error, {:invalid_transition, status, :snoozed}}
      end
    end
  end

  describe "unsnooze/2" do
    test "restarts a snoozed schedule as a fresh backlog row due today" do
      schedule =
        insert(:team_deletion_schedule,
          status: :snoozed,
          is_backlog: false,
          snoozed_until: ~D[2026-09-20],
          snooze_note: "customer asked for time",
          first_notice_sent_at: ~N[2026-07-01 10:00:00],
          reminder_sent_at: ~N[2026-07-20 10:00:00]
        )

      today = ~D[2026-08-20]

      assert {:ok, updated} = TeamDeletionSchedules.unsnooze(schedule, today)
      assert updated.status == :scheduled
      assert updated.is_backlog
      assert updated.first_notice_due_date == today
      assert updated.first_notice_sent_at == nil
      assert updated.reminder_sent_at == nil
      assert updated.snoozed_until == nil
      assert updated.snooze_note == nil
    end

    test "rejects any status other than :snoozed" do
      for status <- TeamDeletionSchedule.statuses() -- [:snoozed] do
        schedule = insert(:team_deletion_schedule, status: status)

        assert TeamDeletionSchedules.unsnooze(schedule, ~D[2026-08-20]) ==
                 {:error, {:invalid_transition, status, :scheduled}}
      end
    end
  end
end
