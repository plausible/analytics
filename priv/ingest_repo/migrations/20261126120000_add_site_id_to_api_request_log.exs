defmodule Plausible.IngestRepo.Migrations.AddSiteIdToApiRequestLog do
  use Ecto.Migration

  import Plausible.MigrationUtils

  @on_cluster on_cluster_statement("events_v2")

  def up do
    if enterprise_edition?() do
      execute """
      ALTER TABLE api_request_log
      #{@on_cluster}
      ADD COLUMN site_id UInt64
      """
    end
  end

  def down do
    if enterprise_edition?() do
      execute """
      ALTER TABLE api_request_log
      #{@on_cluster}
      DROP COLUMN IF EXISTS site_id
      """
    end
  end
end
