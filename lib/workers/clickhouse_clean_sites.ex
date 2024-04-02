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
    "imported_sources",
    "imported_visitors"
  ]

  @settings if Mix.env() in [:test, :small_test], do: [mutations_sync: 2], else: []

  def perform(_job) do
    deleted_sites = get_deleted_sites_with_clickhouse_data()

    if length(deleted_sites) > 0 do
      Logger.info(
        "Clearing ClickHouse data for the following #{length(deleted_sites)} sites which have been deleted: #{inspect(deleted_sites)}"
      )

      site_ids_expr = deleted_sites |> Enum.map_join(", ", &to_string/1)

      for table <- @tables_to_clear do
        IngestRepo.query!(
          "ALTER TABLE #{table} DELETE WHERE site_id IN #{site_ids_expr}",
          [],
          settings: @settings
        )
      end
    end

    :ok
  end

  def get_deleted_sites_with_clickhouse_data() do
    pg_sites =
      from(s in Plausible.Site, select: s.id)
      |> Plausible.Repo.all()
      |> MapSet.new()

    ch_sites =
      from(e in "events_v2", group_by: e.site_id, select: e.site_id)
      |> Plausible.ClickhouseRepo.all(timeout: :infinity)
      |> MapSet.new()

    MapSet.difference(ch_sites, pg_sites) |> MapSet.to_list()
  end
end
