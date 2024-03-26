defmodule Plausible.Workers.ClickhouseCleanSites do
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

  def perform(_job) do
    deleted_sites = get_deleted_sites_with_clickhouse_data()

    if length(deleted_sites) > 0 do
      Logger.info(
        "Clearing ClickHouse data for the following #{length(deleted_sites)} sites which have been deleted: #{inspect(deleted_sites)}"
      )

      site_ids_expr = deleted_sites |> Enum.map(&to_string/1) |> Enum.join(", ")

      for table <- @tables_to_clear do
        IngestRepo.query(
          "ALTER TABLE #{table} DELETE WHERE site_id IN (#{site_ids_expr})",
          [],
          if(Mix.env() == :test, do: [mutations_sync: 2], else: [])
        )
      end
    end

    :ok
  end

  def get_deleted_sites_with_clickhouse_data() do
    pg_sites =
      from(s in Plausible.Site, select: %{id: s.id})
      |> Plausible.Repo.all()
      |> Enum.map(&(&1 |> Map.fetch!(:id)))
      |> MapSet.new()

    ch_sites =
      from(e in "events_v2", group_by: e.site_id, select: %{site_id: e.site_id})
      |> Plausible.ClickhouseRepo.all(timeout: :infinity)
      |> Enum.map(& &1.site_id)
      |> MapSet.new()

    MapSet.difference(ch_sites, pg_sites) |> MapSet.to_list()
  end
end
