defmodule Plausible.ClickhouseRepo.Migrations.RemoveCityNameToImportedLocations do
  use Ecto.Migration

  def change do
    alter table(:imported_locations) do
      remove :city_name
    end
  end
end
