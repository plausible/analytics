defmodule Plausible.Repo.Migrations.RemoveHelpscoutTables do
  use Ecto.Migration

  def change do
    drop table(:help_scout_credentials)
    drop table(:help_scout_mappings)
  end
end
