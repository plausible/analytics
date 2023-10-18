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
    cluster_query = "SELECT 1 FROM system.replicas WHERE table = 'imported_visitors'"

    cluster? =
      case Ecto.Adapters.SQL.query(Plausible.IngestRepo, cluster_query) do
        {:ok, %{rows: []}} -> false
        {:ok, _} -> true
      end

    for table <- @import_tables do
      execute """
      ALTER TABLE #{table} #{if cluster?, do: "ON CLUSTER '{cluster}'"}  MODIFY SETTING replicated_deduplication_window = 0
      """
    end
  end

  def down do
    raise "Irreversible"
  end
end
