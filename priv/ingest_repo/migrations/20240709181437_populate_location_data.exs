defmodule Plausible.IngestRepo.Migrations.PopulateLocationData do
  use Ecto.Migration

  def up do
    try do
      Location.load_all()
    rescue
      _ -> nil
    end

    Plausible.DataMigration.LocationsSync.run()
  end

  def down do
    raise "Irreversible"
  end
end
