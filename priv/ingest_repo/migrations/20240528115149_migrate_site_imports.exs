defmodule Plausible.IngestRepo.Migrations.MigrateSiteImports do
  use Plausible
  use Ecto.Migration

  def up do
    if ce?() do
      Ecto.Migrator.with_repo(Plausible.Repo, fn _repo ->
        {:ok, _, _} =
          Ecto.Migrator.with_repo(Plausible.ClickhouseRepo, fn _repo ->
            Plausible.DataMigration.SiteImports.run(dry_run?: false)
          end)
      end)
    end
  end

  def down do
    raise "Irreversible"
  end
end
