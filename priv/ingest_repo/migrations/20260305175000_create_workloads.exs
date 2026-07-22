defmodule Plausible.IngestRepo.Migrations.CreateWorkloads do
  use Ecto.Migration

  import Plausible.MigrationUtils

  @on_cluster on_cluster_statement("sessions_v2")

  def up do
    if enterprise_edition?() do
      execute "CREATE RESOURCE cpu #{@on_cluster} (MASTER THREAD, WORKER THREAD)"

      execute "CREATE OR REPLACE WORKLOAD all #{@on_cluster}"

      execute "CREATE OR REPLACE WORKLOAD admin #{@on_cluster} IN all SETTINGS max_concurrent_threads = 2, priority = -1"

      execute "CREATE OR REPLACE WORKLOAD ingestion #{@on_cluster} IN all SETTINGS weight = 1, priority = 0"

      execute "CREATE OR REPLACE WORKLOAD default #{@on_cluster} IN all SETTINGS weight = 4, priority = 1, max_cpu_share = 0.90"

      execute "CREATE OR REPLACE WORKLOAD external_api #{@on_cluster} IN all SETTINGS weight = 1, priority = 1, max_cpu_share = 0.25"
    end
  end

  def down do
    if enterprise_edition?() do
      execute "DROP WORKLOAD IF EXISTS admin #{@on_cluster}"
      execute "DROP WORKLOAD IF EXISTS ingestion #{@on_cluster}"
      execute "DROP WORKLOAD IF EXISTS external_api #{@on_cluster}"
      execute "DROP WORKLOAD IF EXISTS default #{@on_cluster}"
      execute "DROP WORKLOAD IF EXISTS all #{@on_cluster}"
      execute "DROP RESOURCE IF EXISTS cpu #{@on_cluster}"
    end
  end
end
