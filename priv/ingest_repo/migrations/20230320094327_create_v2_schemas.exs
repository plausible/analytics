defmodule Plausible.IngestRepo.Migrations.CreateV2Schemas do
  @moduledoc """
  Normally, for live environments the migration will be done via
  `DataMigration.NumericIDs` module.

  For tests, and entirely new small, self-hosted instances however,
  we want to keep the ability of preparing the database without enforcing
  any _data_ migration.
  """

  use Ecto.Migration

  use Plausible.DataMigration, dir: "NumericIDs"

  @cluster? false

  def up do
    table_settings = Plausible.MigrationUtils.table_settings_expr()

    execute unwrap("create-events-v2", table_settings: table_settings, cluster?: @cluster?)
    execute unwrap("create-sessions-v2", table_settings: table_settings, cluster?: @cluster?)
  end

  def down do
    execute unwrap("drop-events-v2", cluster?: @cluster?)
    execute unwrap("drop-sessions-v2", cluster?: @cluster?)
  end
end
