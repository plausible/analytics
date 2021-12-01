defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedLocations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_locations, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :country, :string
      add :region, :string
      add :city, :string
      add :visitors, :UInt64
    end
  end
end
