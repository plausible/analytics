defmodule Plausible.Workers.ClickhouseCleanSites do
  @moduledoc """
  Cleans deleted site data from ClickHouse asynchronously, using lightweight
  deletes.

  Deletes against `events_v2` and `sessions_v2` are scoped to the monthly
  partitions covered by the pending stats deletions, so ClickHouse doesn't
  have to touch partitions we know contain no relevant data. The remaining
  tables aren't partitioned, so they're cleared in one go.

  We batch up data deletions from ClickHouse as deleting a single site is
  just as expensive as deleting many.
  """

  use Plausible.IngestRepo
  use Oban.Worker, queue: :clickhouse_clean_sites

  alias Plausible.PendingStatsDeletions
  alias Plausible.Stats.Clickhouse

  require Logger

  @partitioned_tables ["events_v2", "sessions_v2"]

  @unpartitioned_tables [
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

  # ingest_counters has a projection (`ingest_counters_site_traffic_projection`), 
  # and ClickHouse refuses lightweight deletes against tables with projections 
  # - fall back to a mutation which rebuilds the projection.
  @mutation_only_tables ["ingest_counters"]

  @settings if Mix.env() in [:test, :ce_test, :e2e_test], do: [mutations_sync: 2], else: []

  def perform(_job) do
    case PendingStatsDeletions.list() do
      %{site_ids: []} ->
        :ok

      %{site_ids: site_ids, stats_start: stats_start, stats_end: stats_end} ->
        Logger.notice(
          "Clearing ClickHouse data for #{length(site_ids)} in range #{stats_start}..#{stats_end}"
        )

        for partition_id <- Clickhouse.partition_ids(stats_start, stats_end),
            table <- @partitioned_tables do
          clear_partitioned_table!(table, partition_id, site_ids)
        end

        for table <- @unpartitioned_tables do
          clear_unpartitioned_table!(table, site_ids)
        end

        for table <- @mutation_only_tables do
          clear_table_via_mutation!(table, site_ids)
        end

        :ok
    end
  end

  defp clear_partitioned_table!(table, partition_id, site_ids) do
    IngestRepo.query!(
      "DELETE FROM {$0:Identifier} IN PARTITION ID {$1:String} WHERE site_id IN {$2:Array(UInt64)}",
      [table, partition_id, site_ids],
      settings: @settings
    )
  end

  defp clear_unpartitioned_table!(table, site_ids) do
    IngestRepo.query!(
      "DELETE FROM {$0:Identifier} WHERE site_id IN {$1:Array(UInt64)}",
      [table, site_ids],
      settings: @settings
    )
  end

  defp clear_table_via_mutation!(table, site_ids) do
    IngestRepo.query!(
      "ALTER TABLE {$0:Identifier} DELETE WHERE site_id IN {$1:Array(UInt64)}",
      [table, site_ids],
      settings: @settings
    )
  end
end
