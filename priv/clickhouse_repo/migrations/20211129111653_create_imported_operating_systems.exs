defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedOperatingSystems do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_operating_systems, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :naive_datetime
      add :operating_system, :string
      add :visitors, :UInt64
    end
  end
end
