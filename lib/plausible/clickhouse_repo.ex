defmodule Plausible.ClickhouseRepo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: ClickhouseEcto

  defmacro __using__(_) do
    quote do
      alias Plausible.ClickhouseRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  def clear_stats_for(domain) do
    events_sql = "ALTER TABLE events DELETE WHERE domain = ?"
    sessions_sql = "ALTER TABLE sessions DELETE WHERE domain = ?"
    Ecto.Adapters.SQL.query!(__MODULE__, events_sql, [domain])
    Ecto.Adapters.SQL.query!(__MODULE__, sessions_sql, [domain])
  end

  def clear_imported_stats_for(site_id) do
    [
      "imported_visitors",
      "imported_sources",
      "imported_pages",
      "imported_entry_pages",
      "imported_exit_pages",
      "imported_locations",
      "imported_devices",
      "imported_browsers",
      "imported_operating_systems"
    ]
    |> Enum.map(fn table ->
      sql = "ALTER TABLE #{table} DELETE WHERE site_id = ?"
      Ecto.Adapters.SQL.query!(__MODULE__, sql, [site_id])
    end)
  end
end
