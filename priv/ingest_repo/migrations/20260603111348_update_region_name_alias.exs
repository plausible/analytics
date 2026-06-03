defmodule Plausible.IngestRepo.Migrations.UpdateRegionNameAlias do
  use Ecto.Migration

  def up do
    try do
      Location.load_all()
    rescue
      ArgumentError -> nil
    end

    Plausible.DataMigration.LocationsSync.run()
  end

  def down do
    raise "Irreversible"
  end
end
