defmodule Plausible.PendingStatsDeletions do
  @moduledoc """
  Context for pending stats deletions
  """

  import Ecto.Query

  alias Plausible.ClickhouseRepo
  alias Plausible.PendingStatsDeletion
  alias Plausible.Repo
  alias Plausible.Site

  @spec store(Site.t(), atom()) :: {:ok, PendingStatsDeletion.t()}
  def store(%Site{} = site, reason \\ :user_request) do
    Repo.insert(%PendingStatsDeletion{site_id: site.id, reason: reason})
  end

  @spec list(atom()) :: [pos_integer()]
  def list(reason \\ :user_request) do
    from(p in PendingStatsDeletion,
      where: p.reason == ^reason,
      distinct: true,
      order_by: p.site_id,
      select: p.site_id
    )
    |> Repo.all()
  end

  @spec clear([pos_integer()], atom()) :: {non_neg_integer(), nil}
  def clear(site_ids, reason \\ :user_request)
  def clear([], _reason), do: {0, nil}

  def clear(site_ids, reason) do
    Repo.delete_all(
      from(p in PendingStatsDeletion, where: p.site_id in ^site_ids and p.reason == ^reason)
    )
  end

  # Temporary. Bridges sites deleted before pending stats deletion tracking
  # existed. Finds sites with orphaned ClickHouse data (no matching Postgres
  # site) and records a pending deletion for each, so `ClickhouseCleanSites`
  # picks them up via `list/1`. Safe to run more than once. Remove
  # once it's been run in every environment.
  @spec backfill_orphaned_sites() :: {:ok, non_neg_integer()}
  def backfill_orphaned_sites() do
    already_tracked = MapSet.new(list())
    now = NaiveDateTime.utc_now(:second)

    records =
      orphaned_clickhouse_site_ids()
      |> Enum.reject(&(&1 in already_tracked))
      |> Enum.map(fn site_id ->
        %{site_id: site_id, reason: :user_request, inserted_at: now, updated_at: now}
      end)

    {count, _} = Repo.insert_all(PendingStatsDeletion, records)

    {:ok, count}
  end

  @all_stats_tables [
    "events_v2",
    "sessions_v2",
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

  defp orphaned_clickhouse_site_ids() do
    pg_site_ids =
      from(s in Site.regular(), select: s.id)
      |> Repo.all()
      |> MapSet.new()

    {:ok, ch} =
      Ch.start_link(ClickhouseRepo.get_config_without_ch_query_execution_timeout())

    query =
      Enum.map_join(
        @all_stats_tables,
        "\nUNION DISTINCT\n",
        &"SELECT site_id FROM #{&1} GROUP BY site_id"
      )

    %Ch.Result{columns: ["site_id"], rows: rows} =
      DBConnection.run(
        ch,
        fn conn -> Ch.query!(conn, query, [], timeout: :infinity) end,
        timeout: :infinity
      )

    ch_site_ids = rows |> MapSet.new(fn [site_id] -> site_id end)

    MapSet.difference(ch_site_ids, pg_site_ids) |> MapSet.to_list()
  end
end
