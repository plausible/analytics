defmodule Plausible.ClickhouseRepo.Migrations.AddCityNameToImportedLocations do
  use Ecto.Migration

  def change do
    alter table(:imported_locations) do
      add :city_name, :string
    end
  end
end
