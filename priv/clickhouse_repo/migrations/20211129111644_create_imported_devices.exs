defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedDevices do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_devices, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :device, :string
      add :visitors, :UInt64
    end
  end
end
