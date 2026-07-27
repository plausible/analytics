defmodule Plausible.Workers.ClickhouseCleanSites do
  @moduledoc """
  Cleans deleted site data from ClickHouse sequentially.

  We batch up data deletions from ClickHouse as deleting a single site may be more expensive than deleting many:
  the expense scales with the number of partitions the site or sites have rows in.
  A single site with events since 2025-01 to 2026-06 will be more expensive to clean up
  than a hundred sites with events only in the partition 2026-06.

  Tables are cleaned one partition at a time because to clean one partition,
  Clickhouse needs to rewrite it. It reserves room for rewriting it in full on disk.
  Cleaning all partitions at the same time would mean Clickhouse reserving room on disk
  equal to the size of all the partitions,
  potentially reserving all the available disk space and shorting out INSERTs from ingestion.
  This sequential approach prevents that.
  """

  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.IngestRepo
  use Oban.Worker, queue: :clickhouse_clean_sites

  import Ecto.Query

  require Logger

  @tables_to_clear [
    "events_v2",
    "sessions_v2",
    "ingest_counters",
    "imported_browsers",
    "imported_devices",
    "imported_entry_pages",
    "imported_exit_pages",
    "imported_locations",
    "imported_operating_systems",
    "imported_pages",
    "imported_custom_events",
    "imported_sources",
    "imported_visitors"
  ]

  @settings [mutations_sync: 2]

  @partition_delete_timeout :timer.minutes(15)

  def perform(_job) do
    deleted_sites = get_deleted_sites_with_clickhouse_data()

    if not Enum.empty?(deleted_sites) do
      Logger.notice(
        "Clearing ClickHouse data for the following #{length(deleted_sites)} sites which have been deleted: #{inspect(deleted_sites)}"
      )

      database = current_database()

      for table <- @tables_to_clear do
        clean_sites_from_table(database, table, deleted_sites)
      end
    end

    :ok
  end

  defp clean_sites_from_table(database, table, deleted_sites_ids) do
    for partition_id <- active_partition_ids(database, table) do
      delete_sites_from_partition(table, partition_id, deleted_sites_ids)
    end
  end

  defp delete_sites_from_partition(table, partition_id, deleted_sites_ids) do
    IngestRepo.query!(
      "ALTER TABLE {$0:Identifier} DELETE IN PARTITION ID {$1:String} WHERE site_id IN {$2:Array(UInt64)}",
      [table, partition_id, deleted_sites_ids],
      settings: @settings,
      timeout: @partition_delete_timeout,
      checkout_retries: 0
    )
  end

  defp active_partition_ids(database, table) do
    source =
      if IngestRepo.clustered_table?(table) do
        "clusterAllReplicas('{cluster}', system.parts)"
      else
        "system.parts"
      end

    %Ch.Result{columns: ["partition_id"], rows: rows} =
      IngestRepo.query!(
        """
        SELECT DISTINCT partition_id
        FROM #{source}
        WHERE database = {$0:String} AND table = {$1:String} AND active
        ORDER BY partition_id
        """,
        [database, table]
      )

    Enum.map(rows, fn [partition_id] -> partition_id end)
  end

  defp current_database do
    %Ch.Result{rows: [[database]]} = IngestRepo.query!("SELECT currentDatabase()")
    database
  end

  def get_deleted_sites_with_clickhouse_data() do
    pg_sites =
      from(s in Plausible.Site.regular(), select: s.id)
      |> Plausible.Repo.all()
      |> MapSet.new()

    {:ok, ch} =
      Plausible.ClickhouseRepo.get_config_without_ch_query_execution_timeout()
      |> Ch.start_link()

    %Ch.Result{columns: ["site_id"], rows: rows} =
      DBConnection.run(
        ch,
        fn conn ->
          Ch.query!(conn, site_ids_with_data_query(), [],
            settings: [optimize_distinct_in_order: 1],
            timeout: :infinity
          )
        end,
        timeout: :infinity
      )

    ch_sites = for [site_id] <- rows, not is_nil(site_id), into: MapSet.new(), do: site_id

    MapSet.difference(ch_sites, pg_sites) |> MapSet.to_list()
  end

  defp site_ids_with_data_query do
    Enum.map_join(@tables_to_clear, " UNION DISTINCT ", fn table ->
      "SELECT DISTINCT site_id FROM #{table}"
    end)
  end
end
