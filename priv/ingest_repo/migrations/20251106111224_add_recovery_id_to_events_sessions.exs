defmodule Plausible.IngestRepo.Migrations.AddRecoveryIdToEventsSessions do
  use Ecto.Migration

  import Plausible.MigrationUtils

  @on_cluster_sessions on_cluster_statement("sessions_v2")
  @on_cluster_events on_cluster_statement("events_v2")

  def up do
    if enterprise_edition?() do
      execute """
      ALTER TABLE sessions_v2
      #{@on_cluster_sessions}
      ADD COLUMN recovery_id UInt64
      """

      execute """
      ALTER TABLE events_v2
      #{@on_cluster_events}
      ADD COLUMN recovery_id UInt64
      """
    end
  end

  def down do
    if enterprise_edition?() do
      execute """
      ALTER TABLE sessions_v2
      #{@on_cluster_sessions}
      DROP COLUMN IF EXISTS recovery_id
      """

      execute """
      ALTER TABLE events_v2
      #{@on_cluster_events}
      DROP COLUMN IF EXISTS recovery_id
      """
    end
  end
end
