defmodule Plausible.Repo.Migrations.MigrateSiteImports do
  use Ecto.Migration

  def up do
    if Plausible.ce?() do
      Plausible.DataMigration.SiteImports.run(dry_run?: false)
    end
  end

  def down do
    raise "Irreversible"
  end
end
