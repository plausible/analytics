defmodule Plausible.IngestRepo.Migrations.AddScrollDepthToImportedPages do
  use Ecto.Migration

  def up do
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("imported_pages")

    execute """
    ALTER TABLE imported_pages
    #{on_cluster}
    ADD COLUMN scroll_depth UInt8 DEFAULT 255
    """
  end

  def down do
    raise "Irreversible"
  end
end
