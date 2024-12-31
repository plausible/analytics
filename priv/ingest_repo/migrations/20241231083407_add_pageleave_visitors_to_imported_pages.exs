defmodule Plausible.IngestRepo.Migrations.AddPageleaveVisitorsToImportedPages do
  use Ecto.Migration

  @on_cluster Plausible.MigrationUtils.on_cluster_statement("imported_pages")

  def up do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    ADD COLUMN pageleave_visitors UInt64
    """
  end

  def down do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN pageleave_visitors
    """
  end
end
