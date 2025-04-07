defmodule Plausible.Repo.Migrations.BackfillTeamsHourlyApiRequestLimit do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def up do
    if community_edition?() do
      Plausible.DataMigration.BackfillTeamsHourlyRequestLimit.run(dry_run?: false)
    end
  end

  def down do
    raise "Irreversible"
  end
end
