defmodule Mix.Tasks.CleanClickhouse do
  use Mix.Task

  def run(_) do
    clean_events = "ALTER TABLE events DELETE WHERE 1"
    clean_sessions = "ALTER TABLE sessions DELETE WHERE 1"
    Clickhousex.query(:clickhouse, clean_events, [], log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, clean_sessions, [], log: {Plausible.Clickhouse, :log, []})
  end
end
