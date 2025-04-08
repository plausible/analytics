defmodule Plausible.Repo.Migrations.BackfillTeams do
  use Ecto.Migration

  def up do
    if Plausible.ce?() do
      Plausible.DataMigration.BackfillTeams.run(dry_run?: false)
    end
  end

  def down do
    raise "Irreversible"
  end
end
