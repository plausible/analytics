defmodule Plausible.IngestRepo.Migrations.CreateIngestCountersTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:ingest_counters,
                           primary_key: false,
                           engine: "SummingMergeTree(value)",
                           options: [
                             order_by:
                               "(domain, toDate(event_timebucket), metric, toStartOfMinute(event_timebucket))"
                           ]
                         ) do
      add(:event_timebucket, :utc_datetime)
      add(:domain, :"LowCardinality(String)")
      add(:site_id, :"Nullable(UInt64)")
      add(:metric, :"LowCardinality(String)")
      add(:value, :UInt64)
    end
  end
end
