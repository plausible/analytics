defmodule Plausible.IngestRepo.Migrations.AddBatchToSessionsAndEvents do
  use Ecto.Migration

  @on_cluster_sessions Plausible.MigrationUtils.on_cluster_statement("sessions_v2")
  @on_cluster_events Plausible.MigrationUtils.on_cluster_statement("events_v2")

  def up do
    execute """
    ALTER TABLE sessions_v2
    #{@on_cluster_sessions}
    ADD COLUMN batch UInt64
    """

    execute """
    ALTER TABLE sessions_v2
    #{@on_cluster_sessions}
    ADD INDEX IF NOT EXISTS minmax_batch batch
    TYPE minmax GRANULARITY 1
    """

    execute """
    ALTER TABLE sessions_v2
    MATERIALIZE INDEX minmax_batch
    """

    execute """
    ALTER TABLE events_v2
    #{@on_cluster_events}
    ADD COLUMN batch UInt64
    """

    execute """
    ALTER TABLE events_v2
    #{@on_cluster_events}
    ADD INDEX IF NOT EXISTS minmax_batch batch
    TYPE minmax GRANULARITY 1
    """

    execute """
    ALTER TABLE events_v2
    MATERIALIZE INDEX minmax_batch
    """
  end

  def down do
    execute """
    ALTER TABLE sessions_v2
    #{@on_cluster_sessions}
    DROP INDEX IF EXISTS minmax_batch
    """

    execute """
    ALTER TABLE sessions_v2
    #{@on_cluster_sessions}
    DROP COLUMN IF EXISTS batch
    """

    execute """
    ALTER TABLE events_v2
    #{@on_cluster_events}
    DROP INDEX IF EXISTS minmax_batch
    """

    execute """
    ALTER TABLE events_v2
    #{@on_cluster_events}
    DROP COLUMN IF EXISTS batch
    """
  end
end
