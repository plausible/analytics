defmodule Plausible.IngestRepo.Migrations.CreateIngestCountersSiteTrafficProjection do
  use Ecto.Migration

  def up do
    # ClickHouse 24.8 introduced `deduplicate_merge_projection_mode` which we need to set to create this projection.
    # As such, try to set the setting and if it fails, ignore it.
    execute(fn ->
      try do
        repo().query!("""
          ALTER TABLE ingest_counters
          #{Plausible.MigrationUtils.on_cluster_statement("ingest_counters")}
          MODIFY SETTING deduplicate_merge_projection_mode='rebuild'
        """)
      rescue
        _e -> nil
      end
    end)

    execute """
      ALTER TABLE ingest_counters
      #{Plausible.MigrationUtils.on_cluster_statement("ingest_counters")}
      ADD PROJECTION ingest_counters_site_traffic_projection (
        SELECT site_id, toDate(event_timebucket), sumIf(value, metric = 'buffered')
        GROUP BY site_id, toDate(event_timebucket)
      )
    """

    execute """
      ALTER TABLE ingest_counters
      #{Plausible.MigrationUtils.on_cluster_statement("ingest_counters")}
      MATERIALIZE PROJECTION ingest_counters_site_traffic_projection
    """
  end

  def down do
    raise "irreversible"
  end
end
