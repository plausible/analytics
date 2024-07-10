defmodule Plausible.IngestRepo.Migrations.PopulateLocationData do
  use Ecto.Migration

  def up do
    # Location data may not be loaded, so _try_ to load it. Failure is OK - it means it's loaded.
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
