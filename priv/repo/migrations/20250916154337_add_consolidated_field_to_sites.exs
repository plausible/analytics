defmodule Plausible.Repo.Migrations.AddConsolidatedFieldToSites do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:sites) do
        add :consolidated, :boolean, null: false, default: false
      end
    end
  end
end
