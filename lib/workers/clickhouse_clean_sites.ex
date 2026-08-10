defmodule Plausible.Workers.ClickhouseCleanSites do
  @moduledoc """
  Cleans deleted site data from ClickHouse asynchronously.

  We batch up data deletions from ClickHouse as deleting a single site is
  just as expensive as deleting many.
  """

  use Plausible.IngestRepo
  use Oban.Worker, queue: :clickhouse_clean_sites

  alias Plausible.PendingStatsDeletions

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

  @settings if Mix.env() in [:test, :ce_test, :e2e_test], do: [mutations_sync: 2], else: []

  def perform(_job) do
    deleted_sites = PendingStatsDeletions.list_by_reason().site_ids

    if not Enum.empty?(deleted_sites) do
      Logger.notice(
        "Clearing ClickHouse data for the following #{length(deleted_sites)} sites which have been deleted: #{inspect(deleted_sites)}"
      )

      for table <- @tables_to_clear do
        IngestRepo.query!(
          "ALTER TABLE {$0:Identifier} DELETE WHERE site_id IN {$1:Array(UInt64)}",
          [table, deleted_sites],
          settings: @settings
        )
      end
    end

    :ok
  end
end
