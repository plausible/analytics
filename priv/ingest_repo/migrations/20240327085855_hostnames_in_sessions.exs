defmodule Plausible.ClickhouseRepo.Migrations.HostnamesInSessions do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE sessions_v2
    #{Plausible.MigrationUtils.on_cluster_statement("sessions_v2")}
    ADD COLUMN exit_page_hostname String CODEC(ZSTD(3))
    """
  end

  def down do
    execute """
    ALTER TABLE sessions_v2
    #{Plausible.MigrationUtils.on_cluster_statement("sessions_v2")}
    DROP COLUMN exit_page_hostname
    """
  end
end
