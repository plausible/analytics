defmodule Plausible.Repo.Migrations.RemoveHelpscoutTables do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      drop table(:help_scout_credentials)
      drop table(:help_scout_mappings)
    end
  end
end
