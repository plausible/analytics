defmodule Plausible.Repo.Migrations.MigrateSiteImports do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def up do
    if community_edition?() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(Plausible.ClickhouseRepo, fn _repo ->
          Plausible.DataMigration.SiteImports.run(dry_run?: false)
        end)
    end
  end

  def down do
    raise "Irreversible"
  end
end
