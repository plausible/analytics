defmodule Plausible.IngestRepo.Migrations.AddMetricsToImportedTables do
  use Ecto.Migration

  @add_pageviews_for [
    :imported_browsers,
    :imported_devices,
    :imported_entry_pages,
    :imported_locations,
    :imported_operating_systems,
    :imported_sources
  ]

  def change do
    for table <- @add_pageviews_for do
      alter table(table) do
        add(:pageviews, :UInt64)
      end
    end

    alter table(:imported_pages) do
      add(:visits, :UInt64)
    end

    alter table(:imported_exit_pages) do
      add(:pageviews, :UInt64)
      add(:bounces, :UInt32)
      add(:visit_duration, :UInt64)
    end
  end
end
