defmodule Plausible.Repo.Migrations.AddSetupEmails do
  use Ecto.Migration

  def change do
    create table(:setup_help_emails) do
      add :site_id, references(:sites), null: false, on_delete: :delete_all
      add :timestamp, :naive_datetime
    end

    create table(:setup_success_emails) do
      add :site_id, references(:sites), null: false, on_delete: :delete_all
      add :timestamp, :naive_datetime
    end
  end
end
