defmodule Plausible.IngestRepo.Migrations.ImportedPagesRemoveOldTimeOnPageColumns do
  use Ecto.Migration

  def up do
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("imported_pages")

    execute """
    ALTER TABLE imported_pages
    #{on_cluster}
    DROP COLUMN IF EXISTS time_on_page
    """

    execute """
    ALTER TABLE imported_pages
    #{on_cluster}
    DROP COLUMN IF EXISTS active_visitors
    """
  end

  def down do
    raise "Irreversible"
  end
end
