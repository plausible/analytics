defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedVisitors do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_visitors, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :visitors, :UInt64
      add :pageviews, :UInt64
      add :bounce_rate, :UInt32
      add :avg_visit_duration, :UInt32
    end
  end
end
