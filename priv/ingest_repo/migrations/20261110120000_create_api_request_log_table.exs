defmodule Plausible.IngestRepo.Migrations.CreateApiRequestLogTable do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      on_cluster = on_cluster_statement("events_v2")

      engine =
        if Plausible.IngestRepo.clustered_table?("events_v2") do
          "ReplicatedMergeTree('/clickhouse/{cluster}/tables/{shard}/{database}/api_request_log', '{replica}')"
        else
          "MergeTree()"
        end

      execute """
              CREATE TABLE IF NOT EXISTS api_request_log #{on_cluster}
              (
                `timestamp` DateTime,
                `team_id` UInt64,
                `user_id` UInt64,
                `credential_type` LowCardinality(String),
                `credential_id` UInt64,
                `credential_label` String,
                `interface` LowCardinality(String),
                `operation` LowCardinality(String),
                `status` UInt16,
                `billable` Bool,
                `request_id` String,
                `user_agent` String
              )
              ENGINE = #{engine}
              PARTITION BY toYYYYMM(timestamp)
              ORDER BY (team_id, timestamp)
              TTL timestamp + INTERVAL 3 MONTH
              SETTINGS ttl_only_drop_parts = 1
              #{table_settings_expr(:suffix)}
              """,
              """
              DROP TABLE IF EXISTS api_request_log #{on_cluster} SYNC
              """
    end
  end
end
