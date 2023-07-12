defmodule Plausible.IngestRepo.Migrations.CleanUpOldTablesAfterV2Migration do
  use Ecto.Migration

  def change do
    selfhost? = Application.fetch_env!(:plausible, :is_selfhost)

    unless selfhost? do
      drop_if_exists table(:events)
      drop_if_exists table(:sessions)
    end
  end
end
