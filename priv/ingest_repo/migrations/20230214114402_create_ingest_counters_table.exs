defmodule Plausible.IngestRepo.Migrations.CreateIngestCountersTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:ingest_counters,
      engine: "MergeTree() ORDER BY (domain, toDate(event_timebucket))"
                         ) do

      #  XXX: store site identifier too?
      add(:event_timebucket, :utc_datetime)
      add(:application, :"LowCardinality(String)")
      add(:domain, :"LowCardinality(String)")
      add(:metric, :"LowCardinality(String)")
      add(:value, :Int64)
    end
  end
end
