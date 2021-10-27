defmodule Plausible.Repo.Migrations.AddAnalyticsToGoogleAuth do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:google_auth) do
      add :search_console, :boolean, null: false, default: true
      add :analytics, :string, null: true, default: nil
    end
  end
end
