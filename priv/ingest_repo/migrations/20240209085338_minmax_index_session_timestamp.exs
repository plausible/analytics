defmodule Plausible.IngestRepo.Migrations.MinmaxIndexSessionTimestamp do
  use Ecto.Migration

  def up do
    execute """
      ALTER TABLE sessions_v2
      #{Plausible.MigrationUtils.on_cluster_statement("sessions_v2")}
      ADD INDEX IF NOT EXISTS minmax_timestamp timestamp
      TYPE minmax GRANULARITY 1
    """

    execute """
      ALTER TABLE sessions_v2
      MATERIALIZE INDEX minmax_timestamp
    """
  end

  def down do
    execute """
      ALTER TABLE sessions_v2
      #{Plausible.MigrationUtils.on_cluster_statement("sessions_v2")}
      DROP INDEX IF EXISTS minmax_timestamp
    """
  end
end
