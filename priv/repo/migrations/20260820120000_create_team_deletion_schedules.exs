defmodule Plausible.Repo.Migrations.CreateTeamDeletionSchedules do
  use Ecto.Migration

  def change do
    create table(:team_deletion_schedules) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :category, :text, null: false
      add :expiry_date, :date, null: false
      add :deletion_date, :date, null: false
      add :is_backlog, :boolean, null: false, default: false
      add :status, :text, null: false, default: "scheduled"
      add :first_notice_due_date, :date, null: false
      add :first_notice_sent_at, :naive_datetime
      add :reminder_sent_at, :naive_datetime
      add :snoozed_until, :date
      add :snooze_note, :text

      timestamps()
    end

    create index(:team_deletion_schedules, [:team_id])
    create index(:team_deletion_schedules, [:status])
    create index(:team_deletion_schedules, [:deletion_date])
    create index(:team_deletion_schedules, [:first_notice_due_date])

    # Only one active (i.e. not yet cancelled/completed) schedule per team - a team
    # can churn, come back, and churn again over time, so this isn't a plain
    # unique index on team_id.
    create index(
             :team_deletion_schedules,
             [:team_id],
             unique: true,
             where: "status NOT IN ('cancelled', 'completed')",
             name: :one_active_schedule_per_team
           )
  end
end
