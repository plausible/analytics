defmodule Plausible.Repo.Migrations.AddIntroEmails do
  use Ecto.Migration

  def change do
    create table(:intro_emails) do
      add :user_id, references(:users), null: false
      add :timestamp, :naive_datetime
    end
  end
end
