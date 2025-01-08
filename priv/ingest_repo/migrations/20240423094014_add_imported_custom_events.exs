defmodule Plausible.IngestRepo.Migrations.AddImportedCustomEvents do
  use Ecto.Migration

  def change do
    # NOTE: Using another table for determining cluster presence
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("imported_pages")
    cluster? = Plausible.MigrationUtils.cluster_name()

    cluster_name =
      if cluster? do
        Plausible.MigrationUtils.cluster_name()
      else
        nil
      end

    settings =
      if Plausible.MigrationUtils.cluster_name() do
        """
        ENGINE = ReplicatedMergeTree('/clickhouse/#{cluster_name}/tables/{shard}/{database}/imported_custom_events', '{replica}')
        ORDER BY (site_id, import_id, date, name)
        SETTINGS replicated_deduplication_window = 0, storage_policy = 's3_with_keeper'
        """
      else
        """
        ENGINE = MergeTree()
        ORDER BY (site_id, import_id, date, name)
        SETTINGS replicated_deduplication_window = 0
        """
      end

    execute """
            CREATE TABLE IF NOT EXISTS imported_custom_events #{on_cluster}
                (
                `site_id` UInt64,
                `import_id` UInt64,
                `date` Date,
                `name` String CODEC(ZSTD(3)),
                `link_url` String CODEC(ZSTD(3)),
                `path` String CODEC(ZSTD(3)),
                `visitors` UInt64,
                `events` UInt64
            )
            #{settings}
            """,
            """
            DROP TABLE IF EXISTS imported_custom_events #{on_cluster} SYNC
            """
  end
end
