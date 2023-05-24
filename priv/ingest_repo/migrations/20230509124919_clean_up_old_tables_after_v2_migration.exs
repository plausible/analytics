defmodule Plausible.IngestRepo.Migrations.CleanUpOldTablesAfterV2Migration do
  use Ecto.Migration

  def change do
    drop_if_exists table(:events)
    drop_if_exists table(:sessions)
  end
end
