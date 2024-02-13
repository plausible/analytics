defmodule Plausible.IngestRepo.Migrations.DisableDeduplicationWindowForImports do
  use Ecto.Migration

  @import_tables ~w(
    imported_visitors
    imported_sources
    imported_pages
    imported_entry_pages
    imported_exit_pages
    imported_locations
    imported_devices
    imported_browsers
    imported_operating_systems
  )

  def up do
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("imported_visitors")

    for table <- @import_tables do
      execute """
      ALTER TABLE #{table} #{on_cluster}  MODIFY SETTING replicated_deduplication_window = 0
      """
    end
  end

  def down do
    raise "Irreversible"
  end
end
