defmodule Plausible.Repo.Migrations.AddEnableFeatureFieldsForSite do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :conversions_enabled, :boolean, null: false, default: true
      add :funnels_enabled, :boolean, null: false, default: true
      add :props_enabled, :boolean, null: false, default: true
    end
  end
end
