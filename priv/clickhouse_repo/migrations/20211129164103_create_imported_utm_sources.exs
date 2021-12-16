defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedUtmSources do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_utm_sources, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :utm_source, :string
      add :visitors, :UInt64
      add :visits, :UInt64
      add :visit_duration, :UInt64
      add :bounces, :UInt32
    end
  end
end
