defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedEntryPages do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_entry_pages, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :entry_page, :string
      add :visitors, :UInt64
      add :entrances, :UInt64
      add :visit_duration, :UInt64
      add :bounces, :UInt32
    end
  end
end
