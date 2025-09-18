defmodule Plausible.Repo.Migrations.AddConsolidatedFieldToSites do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:sites) do
        add :consolidated, :boolean, null: false, default: false
      end

      create index(:sites, [:id], where: "consolidated = true")
    end
  end
end
