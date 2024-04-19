defmodule Plausible.IngestRepo.Migrations.AddActiveVisitorsToImportedPages do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE imported_pages
    #{Plausible.MigrationUtils.on_cluster_statement("imported_pages")}
    ADD COLUMN active_visitors UInt64
    """
  end

  def down do
    execute """
    ALTER TABLE imported_pages
    #{Plausible.MigrationUtils.on_cluster_statement("imported_pages")}
    DROP COLUMN active_visitors
    """
  end
end
