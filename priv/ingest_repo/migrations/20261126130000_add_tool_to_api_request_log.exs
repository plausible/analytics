defmodule Plausible.IngestRepo.Migrations.AddToolToApiRequestLog do
  use Ecto.Migration

  import Plausible.MigrationUtils

  @on_cluster on_cluster_statement("events_v2")

  def up do
    if enterprise_edition?() do
      execute """
      ALTER TABLE api_request_log
      #{@on_cluster}
      ADD COLUMN tool LowCardinality(String)
      """
    end
  end

  def down do
    if enterprise_edition?() do
      execute """
      ALTER TABLE api_request_log
      #{@on_cluster}
      DROP COLUMN IF EXISTS tool
      """
    end
  end
end
