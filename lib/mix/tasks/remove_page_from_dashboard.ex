defmodule Mix.Tasks.RemovePageFromDashboard do
  use Mix.Task
  use Plausible.ClickhouseRepo
  require Logger

  def run([domain, page]) do
    events_sql = "ALTER TABLE events DELETE WHERE domain = ? AND pathname = ?"

    sessions_sql =
      "ALTER TABLE sessions DELETE WHERE domain = ? AND entry_page = ? OR exit_page = ?"

    Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, events_sql, [domain, page])
    Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, sessions_sql, [domain, page, page])
  end
end
