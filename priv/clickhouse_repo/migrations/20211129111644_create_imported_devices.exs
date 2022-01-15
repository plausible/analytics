defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedDevices do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_devices, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :naive_datetime
      add :device, :string
      add :visitors, :UInt64
      add :visits, :UInt64
      add :visit_duration, :UInt64
      add :bounces, :UInt32
    end
  end
end
