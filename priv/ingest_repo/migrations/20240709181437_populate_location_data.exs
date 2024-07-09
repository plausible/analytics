defmodule Plausible.IngestRepo.Migrations.PopulateLocationData do
  use Ecto.Migration

  def up do
    Plausible.DataMigration.LocationsSync.run()
  end

  def down do
    raise "Irreversible"
  end
end
