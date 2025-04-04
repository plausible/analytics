defmodule Plausible.Repo.Migrations.BackfillTeamsHourlyApiRequestLimit do
  use Plausible
  use Ecto.Migration

  def up do
    if ce?() do
      Plausible.DataMigration.BackfillTeamsHourlyRequestLimit.run(dry_run?: false)
    end
  end

  def down do
    raise "Irreversible"
  end
end
