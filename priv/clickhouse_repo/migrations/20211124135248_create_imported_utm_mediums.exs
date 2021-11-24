defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedUtmMediums do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_utm_mediums, engine: "MergeTree() ORDER BY (timestamp) SETTINGS index_granularity = 1") do
      add :domain, :string
      add :timestamp, :naive_datetime
      add :utm_medium, :string
      add :visitors, :UInt64
    end
  end
end
