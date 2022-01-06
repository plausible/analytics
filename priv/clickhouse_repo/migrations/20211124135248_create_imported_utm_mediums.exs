defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedUtmMediums do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_utm_mediums, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :naive_datetime
      add :utm_medium, :string
      add :visitors, :UInt64
      add :visits, :UInt64
      add :visit_duration, :UInt64
      add :bounces, :UInt32
    end
  end
end
