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
end
