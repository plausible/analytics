defmodule Plausible.IngestRepo.Migrations.SessionsV2VersionedCollapsingMergeTree do
  use Ecto.Migration

  def up do
    Plausible.DataMigration.VersionedSessions.run(run_exchange?: true)

    # After this migration a `sessions_v2_tmp_versioned` backup table is left behind, to be cleaned up manually
  end

  def down do
    raise "Irreversible"
  end
end
