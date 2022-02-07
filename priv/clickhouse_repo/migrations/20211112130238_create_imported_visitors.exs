defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedVisitors do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_visitors, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :date
      add :visitors, :UInt64
      add :pageviews, :UInt64
      add :bounces, :UInt64
      add :visits, :UInt64
      add :visit_duration, :UInt64
    end
  end
end
