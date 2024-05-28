defmodule Plausible.IngestRepo.Migrations.AddMetricsToImportedTables do
  use Ecto.Migration

  @add_pageviews_for [
    "imported_browsers",
    "imported_devices",
    "imported_entry_pages",
    "imported_exit_pages",
    "imported_locations",
    "imported_operating_systems",
    "imported_sources"
  ]

  def up do
    for table <- @add_pageviews_for do
      add_column(table, "pageviews", "UInt64")
    end

    add_column("imported_browsers", "browser_version", "String")
    add_column("imported_exit_pages", "bounces", "UInt32")
    add_column("imported_exit_pages", "visit_duration", "UInt64")
    add_column("imported_operating_systems", "operating_system_version", "String")
    add_column("imported_pages", "visits", "UInt64")
    add_column("imported_sources", "referrer", "String")
    add_column("imported_sources", "utm_source", "String")
  end

  defp add_column(table, column, type) do
    execute """
    ALTER TABLE #{table}
    #{Plausible.MigrationUtils.on_cluster_statement(table)}
    ADD COLUMN #{column} #{type}
    """
  end
end
