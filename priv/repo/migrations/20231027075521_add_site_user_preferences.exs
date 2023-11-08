defmodule Plausible.Repo.Migrations.AddSiteUserPreferences do
  use Ecto.Migration

  def change do
    create table(:site_user_preferences) do
      add :pinned_at, :naive_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:site_user_preferences, [:user_id, :site_id])
  end
end
