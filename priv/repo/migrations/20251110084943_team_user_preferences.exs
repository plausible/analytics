defmodule Plausible.Repo.Migrations.TeamUserPreferences do
  use Ecto.Migration

  def change do
    create table(:team_user_preferences) do
      add :consolidated_view_cta_dismissed, :boolean, default: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:team_user_preferences, [:user_id, :team_id])
  end
end
