defmodule Plausible.IngestRepo.Migrations.CleanUpOldTablesAfterV2Migration do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    unless community_edition?() do
      drop_if_exists table(:events)
      drop_if_exists table(:sessions)
    end
  end
end
