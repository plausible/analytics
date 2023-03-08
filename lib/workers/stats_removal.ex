defmodule Plausible.Workers.StatsRemoval do
  @moduledoc """
  Asynchronous worker firing deletion mutations to clickhouse.
  For now only ALTER TABLE deletions are supported. Experimental
  DELETE FROM support is going to be introduced once production db
  is upgraded.

  At most 3 attempts are made, with 15m backoff value.

  Imported stats tables keep site reference through a numeric id, whilist
  events and sessions store domain as-is - hence two different deletes,
  one of which cannot be performed anymore once the site identifier is permanently
  gone from postgres.
  """
  use Plausible.Repo

  use Oban.Worker,
    queue: :site_stats_removal,
    max_attempts: 3,
    unique: [period: :infinity, fields: [:args]]

  @impl Oban.Worker
  def perform(%{args: args}) do
    domain = Map.fetch!(args, "domain")
    site_id = Map.get(args, "site_id")

    imported_result = delete_imported!(site_id)
    native_result = delete_native!(domain)

    {:ok, Map.merge(imported_result, native_result)}
  end

  @impl Oban.Worker
  def backoff(_job) do
    15 * 60
  end

  defp delete_imported!(nil) do
    %{}
  end

  defp delete_imported!(id) when is_integer(id) do
    Enum.map(Plausible.Imported.tables(), fn table ->
      sql = "ALTER TABLE #{table} DELETE WHERE site_id = {$0:UInt64}"
      {table, Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, sql, [id])}
    end)
    |> Enum.into(%{})
  end

  defp delete_native!(domain) do
    events_sql = "ALTER TABLE events DELETE WHERE domain = {$0:String}"
    sessions_sql = "ALTER TABLE sessions DELETE WHERE domain = {$0:String}"

    %{
      "events" => Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, events_sql, [domain]),
      "sessions" => Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, sessions_sql, [domain])
    }
  end
end
