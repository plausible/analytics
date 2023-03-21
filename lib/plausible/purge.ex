defmodule Plausible.Purge do
  @moduledoc """
  Deletes data from a site.

  Stats are stored on Clickhouse, and unlike other databases data deletion is
  done asynchronously.

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
      Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, sql, [site.id])
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
