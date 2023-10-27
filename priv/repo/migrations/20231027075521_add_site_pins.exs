defmodule Plausible.Repo.Migrations.AddPinnedSites do
  use Ecto.Migration

  def change do
    create table(:site_pins) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:site_pins, [:user_id, :site_id])
  end
end
