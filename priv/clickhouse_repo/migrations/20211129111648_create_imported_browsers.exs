defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedBrowsers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_browsers, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :browser, :string
      add :version, :string
      add :visitors, :UInt64
    end
  end
end
