defmodule Plausible.TeamDeletionScheduleTest do
  use Plausible.DataCase, async: true

  alias Plausible.TeamDeletionSchedule

  describe "schema" do
    test "inserts a valid schedule with expected defaults" do
      team = insert(:team)
      today = Date.utc_today()
      deletion_date = Date.shift(today, day: 60)

      assert {:ok, schedule} =
               %TeamDeletionSchedule{
                 team_id: team.id,
                 category: :expired_trial,
                 expiry_date: today,
                 deletion_date: deletion_date,
                 first_notice_due_date: Date.shift(deletion_date, day: -30)
               }
               |> Repo.insert()

      assert schedule.status == :scheduled
      assert schedule.is_backlog == false
      assert is_nil(schedule.first_notice_sent_at)
      assert is_nil(schedule.reminder_sent_at)
      assert is_nil(schedule.snoozed_until)
    end

    test "accepts both categories" do
      team1 = insert(:team)
      team2 = insert(:team)
      today = Date.utc_today()

      assert {:ok, %{category: :expired_trial}} =
               Repo.insert(%TeamDeletionSchedule{
                 team_id: team1.id,
                 category: :expired_trial,
                 expiry_date: today,
                 deletion_date: Date.shift(today, day: 60),
                 first_notice_due_date: Date.shift(today, day: 30)
               })

      assert {:ok, %{category: :churned_subscription}} =
               Repo.insert(%TeamDeletionSchedule{
                 team_id: team2.id,
                 category: :churned_subscription,
                 expiry_date: today,
                 deletion_date: Date.shift(today, day: 180),
                 first_notice_due_date: Date.shift(today, day: 150)
               })
    end

    test "rejects an invalid category" do
      team = insert(:team)
      today = Date.utc_today()

      assert_raise Ecto.ChangeError, fn ->
        Repo.insert(%TeamDeletionSchedule{
          team_id: team.id,
          category: :not_a_real_category,
          expiry_date: today,
          deletion_date: today,
          first_notice_due_date: today
        })
      end
    end

    test "rejects an invalid status" do
      team = insert(:team)
      today = Date.utc_today()

      assert_raise Ecto.ChangeError, fn ->
        Repo.insert(%TeamDeletionSchedule{
          team_id: team.id,
          category: :expired_trial,
          status: :not_a_real_status,
          expiry_date: today,
          deletion_date: today,
          first_notice_due_date: today
        })
      end
    end

    test "categories/0 and statuses/0 expose the valid enum values" do
      assert TeamDeletionSchedule.categories() == [:expired_trial, :churned_subscription]

      assert TeamDeletionSchedule.statuses() == [
               :scheduled,
               :first_notice_sent,
               :reminder_sent,
               :completed,
               :cancelled,
               :snoozed
             ]
    end

    test "terminal_statuses/0 and active_statuses/0 partition statuses/0" do
      terminal = TeamDeletionSchedule.terminal_statuses()
      active = TeamDeletionSchedule.active_statuses()

      assert Enum.sort(terminal ++ active) == Enum.sort(TeamDeletionSchedule.statuses())
    end
  end

  describe "team_id foreign key" do
    test "deleting the team cascades to the schedule" do
      schedule = insert(:team_deletion_schedule)

      Repo.delete!(schedule.team)

      refute Repo.get(TeamDeletionSchedule, schedule.id)
    end

    test "rejects a schedule for a non-existent team" do
      today = Date.utc_today()

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%TeamDeletionSchedule{
          team_id: -1,
          category: :expired_trial,
          expiry_date: today,
          deletion_date: today,
          first_notice_due_date: today
        })
      end
    end
  end

  describe "one_active_schedule_per_team index" do
    test "rejects a second active schedule for the same team" do
      team = insert(:team)
      today = Date.utc_today()

      base = %{
        team_id: team.id,
        category: :expired_trial,
        expiry_date: today,
        deletion_date: Date.shift(today, day: 60),
        first_notice_due_date: Date.shift(today, day: 30)
      }

      assert {:ok, _} = Repo.insert(struct(TeamDeletionSchedule, base))

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(struct(TeamDeletionSchedule, Map.put(base, :status, :first_notice_sent)))
      end
    end

    test "allows a new schedule once the previous one is cancelled" do
      team = insert(:team)
      today = Date.utc_today()

      base = %{
        team_id: team.id,
        category: :expired_trial,
        expiry_date: today,
        deletion_date: Date.shift(today, day: 60),
        first_notice_due_date: Date.shift(today, day: 30)
      }

      assert {:ok, _} =
               struct(TeamDeletionSchedule, Map.put(base, :status, :cancelled))
               |> Repo.insert()

      assert {:ok, _} = Repo.insert(struct(TeamDeletionSchedule, base))
    end

    test "allows a new schedule once the previous one is completed" do
      team = insert(:team)
      today = Date.utc_today()

      base = %{
        team_id: team.id,
        category: :churned_subscription,
        expiry_date: today,
        deletion_date: Date.shift(today, day: 180),
        first_notice_due_date: Date.shift(today, day: 150)
      }

      assert {:ok, _} =
               struct(TeamDeletionSchedule, Map.put(base, :status, :completed))
               |> Repo.insert()

      assert {:ok, _} = Repo.insert(struct(TeamDeletionSchedule, base))
    end

    test "allows active schedules for different teams" do
      team1 = insert(:team)
      team2 = insert(:team)
      today = Date.utc_today()

      for team <- [team1, team2] do
        assert {:ok, _} =
                 Repo.insert(%TeamDeletionSchedule{
                   team_id: team.id,
                   category: :expired_trial,
                   expiry_date: today,
                   deletion_date: Date.shift(today, day: 60),
                   first_notice_due_date: Date.shift(today, day: 30)
                 })
      end
    end
  end
end
