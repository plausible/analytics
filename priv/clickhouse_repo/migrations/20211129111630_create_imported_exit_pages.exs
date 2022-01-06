defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedExitPages do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_exit_pages, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :site_id, :UInt64
      add :timestamp, :naive_datetime
      add :exit_page, :string
      add :visitors, :UInt64
      add :exits, :UInt64
    end
  end
end
