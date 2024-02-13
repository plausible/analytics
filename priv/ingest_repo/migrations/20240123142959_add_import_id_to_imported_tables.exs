defmodule Plausible.IngestRepo.Migrations.AddImportIdToImportedTables do
  use Ecto.Migration

  @imported_tables [
    :imported_browsers,
    :imported_devices,
    :imported_entry_pages,
    :imported_exit_pages,
    :imported_locations,
    :imported_operating_systems,
    :imported_pages,
    :imported_sources,
    :imported_visitors
  ]

  def change do
    for table <- @imported_tables do
      alter table(table) do
        add(:import_id, :UInt64)
      end
    end
  end
end
