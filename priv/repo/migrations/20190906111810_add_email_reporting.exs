defmodule Plausible.Repo.Migrations.AddEmailReporting do
  use Ecto.Migration

  def change do
    create table(:email_settings) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps()
    end

    create table(:sent_email_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :year, :integer
      add :week, :integer

      add :timestamp, :naive_datetime
    end
  end
end
