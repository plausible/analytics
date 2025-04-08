defmodule Plausible.Repo.Migrations.BackfillTeams do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def up do
    if community_edition?() do
      Plausible.DataMigration.BackfillTeams.run(dry_run?: false)
    end
  end

  def down do
    raise "Irreversible"
  end
end
