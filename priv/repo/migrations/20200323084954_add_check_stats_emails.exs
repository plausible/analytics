defmodule Plausible.Repo.Migrations.AddCheckStatsEmails do
  use Ecto.Migration

  def change do
    create table(:check_stats_emails) do
      add :user_id, references(:users), null: false, on_delete: :delete_all
      add :timestamp, :naive_datetime
    end
  end
end
