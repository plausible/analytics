defmodule Plausible.IngestRepo.Migrations.RenameRecoveryIdToReplaySessionId do
  use Ecto.Migration

  import Plausible.MigrationUtils

  @on_cluster_sessions on_cluster_statement("sessions_v2")
  @on_cluster_events on_cluster_statement("events_v2")

  def up do
    if enterprise_edition?() do
      execute """
      ALTER TABLE sessions_v2
      #{@on_cluster_sessions}
      RENAME COLUMN IF EXISTS recovery_id TO replay_session_id
      """

      execute """
      ALTER TABLE events_v2
      #{@on_cluster_events}
      RENAME COLUMN IF EXISTS recovery_id TO replay_session_id
      """
    end
  end

  def down do
    if enterprise_edition?() do
      execute """
      ALTER TABLE sessions_v2
      #{@on_cluster_sessions}
      RENAME COLUMN IF EXISTS replay_session_id TO recovery_id
      """

      execute """
      ALTER TABLE events_v2
      #{@on_cluster_events}
      RENAME COLUMN IF EXISTS replay_session_id TO recovery_id
      """
    end
  end
end
