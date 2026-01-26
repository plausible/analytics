defmodule Plausible.Workers.ClickhouseCleanSites do
  @moduledoc """
  Cleans deleted site data from ClickHouse asynchronously.

  We batch up data deletions from ClickHouse as deleting a single site is
  just as expensive as deleting many.
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

  @settings if Mix.env() in [:test, :ce_test], do: [mutations_sync: 2], else: []

  def perform(_job) do
    deleted_sites = get_deleted_sites_with_clickhouse_data()

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
          Ch.query!(conn, "FROM events_v2 SELECT site_id GROUP BY site_id", [],
            timeout: :infinity
          )
        end,
        timeout: :infinity
      )

    ch_sites = rows |> MapSet.new(fn [site_id] -> site_id end)

    MapSet.difference(ch_sites, pg_sites) |> MapSet.to_list()
  end
end
