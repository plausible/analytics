defmodule Plausible.Repo.Migrations.CreateGoogleSearchConsoleIntegration do
  use Ecto.Migration

  def change do
    create table(:google_auth) do
      add :site_id, references(:sites), null: false
      add :user_id, references(:users), null: false
      add :refresh_token, :string, null: false
      add :access_token, :string, null: false
      add :expires, :naive_datetime, null: false

      timestamps()
    end

    create unique_index(:google_auth, :site_id)
  end
end
