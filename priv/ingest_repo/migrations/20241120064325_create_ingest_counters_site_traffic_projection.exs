defmodule Plausible.IngestRepo.Migrations.CreateIngestCountersSiteTrafficProjection do
  use Ecto.Migration

  def up do
    execute """
      ALTER TABLE ingest_counters
      #{Plausible.MigrationUtils.on_cluster_statement("ingest_counters")}
      ADD PROJECTION ingest_counters_site_traffic_projection (
        SELECT site_id, toDate(event_timebucket), sumIf(value, metric = 'buffered')
        GROUP BY site_id, toDate(event_timebucket)
      )
    """
  end

  def down do
    execute """
      ALTER TABLE ingest_counters
      #{Plausible.MigrationUtils.on_cluster_statement("ingest_counters")}
      DROP PROJECTION ingest_counters_site_traffic_projection
    """
  end
end
