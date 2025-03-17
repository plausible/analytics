defmodule Plausible.IngestRepo.Migrations.IngestCountersTrackerScriptVersion do
  use Ecto.Migration

  def change do
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("ingest_counters")

    execute """
    ALTER TABLE ingest_counters
    #{on_cluster}
    ADD COLUMN IF NOT EXISTS tracker_script_version UInt16,
    MODIFY ORDER BY (domain, toDate(event_timebucket), metric, toStartOfMinute(event_timebucket), tracker_script_version)
    """
  end
end
