defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedPages do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_pages, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :date
      add :page, :string
      add :visitors, :UInt64
      add :pageviews, :UInt64
      add :time_on_page, :UInt64
    end
  end
end
