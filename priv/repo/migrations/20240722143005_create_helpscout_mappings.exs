defmodule Plausible.Repo.Migrations.CreateHelpscoutMappings do
  use Plausible
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create table(:help_scout_mappings) do
        add :customer_id, :string, null: false
        add :email, :string, null: false

        timestamps()
      end

      create unique_index(:help_scout_mappings, [:customer_id])
    end
  end
end
