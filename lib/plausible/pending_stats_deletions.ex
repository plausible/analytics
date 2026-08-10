defmodule Plausible.PendingStatsDeletions do
  @moduledoc """
  Context for pending stats deletions
  """

  import Ecto.Query

  alias Plausible.ClickhouseRepo
  alias Plausible.PendingStatsDeletion
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Sites

  @spec store(Site.t(), atom()) :: {:ok, PendingStatsDeletion.t() | nil}
  def store(%Site{} = site, reason \\ :user_request) do
    case Sites.stats_range(site) do
      %{stats_start_date: nil, stats_end_date: nil} ->
        {:ok, nil}

      %{stats_start_date: stats_start_date, stats_end_date: stats_end_date} ->
        Repo.insert(%PendingStatsDeletion{
          site_id: site.id,
          stats_start_date: stats_start_date,
          stats_end_date: stats_end_date,
          reason: reason
        })
    end
  end

  @spec list_by_reason(atom()) :: %{
          site_ids: [pos_integer()],
          stats_start: Date.t() | nil,
          stats_end: Date.t() | nil
        }
  def list_by_reason(reason \\ :user_request) do
    Repo.one(
      from(p in PendingStatsDeletion,
        where: p.reason == ^reason,
        select: %{
          site_ids:
            fragment(
              "coalesce(array_agg(DISTINCT ? ORDER BY ?), ARRAY[]::integer[])",
              p.site_id,
              p.site_id
            ),
          stats_start: min(p.stats_start_date),
          stats_end: max(p.stats_end_date)
        }
      )
    )
  end

  # Temporary. Bridges sites deleted before pending stats deletion tracking
  # existed. Finds sites with orphaned ClickHouse data (no matching Postgres
  # site) and records a pending deletion for each, so `ClickhouseCleanSites`
  # picks them up via `list_by_reason/1`. Safe to run more than once. Remove
  # once it's been run in every environment.
  @spec backfill_orphaned_sites() :: {:ok, non_neg_integer()}
  def backfill_orphaned_sites() do
    already_tracked = MapSet.new(list_by_reason().site_ids)

    count =
      orphaned_clickhouse_site_ids()
      |> Enum.reject(&(&1 in already_tracked))
      |> clickhouse_stats_ranges()
      |> Enum.map(fn %{site_id: site_id, stats_start_date: start_date, stats_end_date: end_date} ->
        Repo.insert!(%PendingStatsDeletion{
          site_id: site_id,
          stats_start_date: start_date,
          stats_end_date: end_date,
          reason: :user_request
        })
      end)
      |> length()

    {:ok, count}
  end

  defp orphaned_clickhouse_site_ids() do
    pg_site_ids =
      from(s in Site.regular(), select: s.id)
      |> Repo.all()
      |> MapSet.new()

    {:ok, ch} =
      ClickhouseRepo.get_config_without_ch_query_execution_timeout()
      |> Ch.start_link()

    %Ch.Result{columns: ["site_id"], rows: rows} =
      DBConnection.run(
        ch,
        fn conn ->
          Ch.query!(
            conn,
            """
            SELECT site_id FROM events_v2 GROUP BY site_id
            UNION DISTINCT
            SELECT site_id FROM sessions_v2 GROUP BY site_id
            """,
            [],
            timeout: :infinity
          )
        end,
        timeout: :infinity
      )

    ch_site_ids = rows |> MapSet.new(fn [site_id] -> site_id end)

    MapSet.difference(ch_site_ids, pg_site_ids) |> MapSet.to_list()
  end

  defp clickhouse_stats_ranges([]), do: []

  defp clickhouse_stats_ranges(site_ids) do
    ["events_v2", "sessions_v2"]
    |> Enum.flat_map(&clickhouse_table_stats_ranges(&1, site_ids))
    |> Enum.group_by(& &1.site_id)
    |> Enum.map(fn {site_id, ranges} ->
      %{
        site_id: site_id,
        stats_start_date: ranges |> Enum.map(& &1.stats_start_date) |> Enum.min(Date),
        stats_end_date: ranges |> Enum.map(& &1.stats_end_date) |> Enum.max(Date)
      }
    end)
  end

  defp clickhouse_table_stats_ranges(table, site_ids) do
    from(e in table,
      where: e.site_id in ^site_ids,
      group_by: e.site_id,
      select: %{
        site_id: e.site_id,
        stats_start_date: fragment("toDate(min(?))", e.timestamp),
        stats_end_date: fragment("toDate(max(?))", e.timestamp)
      }
    )
    |> ClickhouseRepo.all()
  end
end
