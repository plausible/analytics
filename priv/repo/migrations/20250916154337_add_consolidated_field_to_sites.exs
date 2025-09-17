defmodule Plausible.Repo.Migrations.AddConsolidatedFieldToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :consolidated, :boolean, null: false, default: false
    end
  end
end
