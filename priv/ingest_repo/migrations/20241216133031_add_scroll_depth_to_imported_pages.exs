defmodule Plausible.IngestRepo.Migrations.AddScrollDepthToImportedPages do
  use Ecto.Migration

  @on_cluster Plausible.MigrationUtils.on_cluster_statement("imported_pages")

  def up do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    ADD COLUMN scroll_depth UInt8 DEFAULT 255
    """
  end

  def down do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN IF EXISTS scroll_depth
    """
  end
end
