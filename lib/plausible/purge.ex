defmodule Plausible.Purge do
  @moduledoc """
  Deletes data from a site.

  Stats are stored on Clickhouse, and unlike other databases data deletion is
  done asynchronously.

  All import tables have MergeTree's deduplication mechanism _disabled_ by setting
  `replicated_deduplication_window` from default 100 to 0. When enabled, every insert
  into a given table is compared against hashes of 100 previous inserts (as complete
  parts, not concrete rows) and ignored when match is found. The prupose of that
  mechanism is making inserts of exact same batches idempotent when retrying them
  shortly after - for instance due to timeout, when the client can't easily tell if
  previous insert succeeded or not. Deduplication, however, only considers inserts,
  not mutations. Deletions do not affect stored hashes, so further inserts of parts
  that were deleted will still be treated as duplicates. That's why this feature
  is disabled for import tables.

  Although deletions are asynchronous, the parts to delete are "remembered", so there's
  no risk of overlapping deletion causing problems with import following right after it.

  IMPORTANT: Deletion requires revision if/when import tables get moved to sharded CH
  cluster setup. Mutation queries, which have to be run with `ON CLUSTER` in such setup,
  dispatch independent queries across shards and those queries can start at different
  times. This in turn means risk of deletions corrupting data of follow-up inserts
  in some edge cases. Ideally, imported entries should be unique for a given import
  - an extra `import_id` column can be introduced, holding identifier.  Last processed
  import identifier should be stored with other site data and should be used for scoping
  imported stats queries. No longer used imports can then be safely removed fully
  asynchronously.

  - [Clickhouse `ALTER TABLE ... DELETE` Statement](https://clickhouse.com/docs/en/sql-reference/statements/alter/delete)
  - [Synchronicity of `ALTER` Queries](https://clickhouse.com/docs/en/sql-reference/statements/alter/#synchronicity-of-alter-queries)
  """

  @spec delete_imported_stats!(Plausible.Site.t()) :: :ok
  @doc """
  Deletes imported stats from Google Analytics, and clears the
  `stats_start_date` field.
  """
  def delete_imported_stats!(site) do
    Enum.each(Plausible.Imported.tables(), fn table ->
      sql = "ALTER TABLE #{table} DELETE WHERE site_id = {$0:UInt64}"
      Ecto.Adapters.SQL.query!(Plausible.ImportDeletionRepo, sql, [site.id])
    end)

    clear_stats_start_date!(site)

    :ok
  end

  @spec delete_native_stats!(Plausible.Site.t()) :: :ok
  @doc """
  Move stats pointers so that no historical stats are available.
  """
  def delete_native_stats!(site) do
    reset!(site)

    :ok
  end

  def reset!(site) do
    site
    |> Ecto.Changeset.change(
      native_stats_start_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      stats_start_date: nil
    )
    |> Plausible.Repo.update!()
  end

  defp clear_stats_start_date!(site) do
    site
    |> Ecto.Changeset.change(stats_start_date: nil)
    |> Plausible.Repo.update!()
  end
end
