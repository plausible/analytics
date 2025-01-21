defmodule Plausible.IngestRepo.Migrations.DropAndAddScrollDepthToImportedPages do
  use Ecto.Migration

  @on_cluster Plausible.MigrationUtils.on_cluster_statement("imported_pages")

  def up do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN scroll_depth
    """

    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    ADD COLUMN scroll_depth Nullable(UInt64)
    """
  end

  def down do
    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN scroll_depth
    """
  end
end
