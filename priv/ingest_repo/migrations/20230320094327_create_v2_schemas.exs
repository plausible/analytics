defmodule Plausible.IngestRepo.Migrations.CreateV2Schemas do
  @moduledoc """
  Normally, for live environments the migration will be done via
  `DataMigration.NumericIDs` module (TBD). In which case PASS_V2_SCHEMA_MIGRATION
  environment variable needs to be set, to only make the standard migrate
  command write an entry into schema_migrations.

  For tests, and entirely new small, self-hosted instances however, 
  we want to keep the ability of preparing the database without enforcing 
  any data migration.
  """

  use Ecto.Migration

  use Plausible.DataMigration, dir: "NumericIDs"

  @cluster? false
  @settings "SETTINGS index_granularity = 8192"

  def up do
    if System.get_env("PASS_V2_SCHEMA_MIGRATION") do
      :ok
    else
      execute unwrap("create-events-v2", table_settings: @settings, cluster?: @cluster?)
      execute unwrap("create-sessions-v2", table_settings: @settings, cluster?: @cluster?)
    end
  end

  def down do
    execute unwrap("drop-events-v2", cluster?: @cluster?)
    execute unwrap("drop-sessions-v2", cluster?: @cluster?)
  end
end
