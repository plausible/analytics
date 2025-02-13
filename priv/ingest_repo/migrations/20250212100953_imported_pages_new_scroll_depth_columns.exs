defmodule Plausible.IngestRepo.Migrations.ImportedPagesNewScrollDepthColumns do
  use Ecto.Migration

  @on_cluster Plausible.MigrationUtils.on_cluster_statement("imported_pages")

  def up do
    execute """
    ALTER TABLE imported_pages #{@on_cluster}
    ADD COLUMN total_scroll_depth UInt64
    """

    execute """
    ALTER TABLE imported_pages #{@on_cluster}
    ADD COLUMN total_scroll_depth_visits UInt64
    """

    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN scroll_depth
    """

    execute """
    ALTER TABLE imported_pages
    #{@on_cluster}
    DROP COLUMN pageleave_visitors
    """
  end

  def down do
    raise "irreversible"
  end
end
