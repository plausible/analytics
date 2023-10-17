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

  def change do
    for table <- @import_tables do
      execute """
              ALTER TABLE #{table} MODIFY SETTING replicated_deduplication_window = 0
              """,
              """
              ALTER TABLE #{table} MODIFY SETTING replicated_deduplication_window = 100
              """
    end
  end
end
