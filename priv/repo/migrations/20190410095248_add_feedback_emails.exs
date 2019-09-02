defmodule Plausible.Repo.Migrations.AddFeedbackEmails do
  use Ecto.Migration

  def change do
    create table(:feedback_emails) do
      add :user_id, references(:users), null: false
      add :timestamp, :naive_datetime, null: false
    end
  end
end
