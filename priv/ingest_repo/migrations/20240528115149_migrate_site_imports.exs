defmodule Plausible.IngestRepo.Migrations.MigrateSiteImports do
  use Ecto.Migration

  def up do
    if Plausible.ce?() do
      Ecto.Migrator.with_repo(Plausible.Repo, fn _repo ->
        %Postgrex.Result{rows: rows} =
          Plausible.Repo.query!(
            "select inserted_at from schema_migrations where version=20240528115149"
          )

        case rows do
          [[already_ran_at]] ->
            IO.puts(
              "skipping site_imports migration since it has already been run at #{already_ran_at}"
            )

            nil

          [] ->
            {:ok, _, _} =
              Ecto.Migrator.with_repo(Plausible.ClickhouseRepo, fn _repo ->
                Plausible.DataMigration.SiteImports.run(dry_run?: false)
              end)
        end
      end)
    end
  end

  def down do
    raise "Irreversible"
  end
end
