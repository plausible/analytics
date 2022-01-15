defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedLocations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_locations, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :naive_datetime
      add :country, :string
      add :region, :string
      add :city, :UInt64
      add :visitors, :UInt64
      add :visits, :UInt64
      add :visit_duration, :UInt64
      add :bounces, :UInt32
    end
  end
end
