defmodule Mix.Tasks.CleanClickhouse do
  use Mix.Task

  def run(_) do
    clean_events = "ALTER TABLE events DELETE WHERE 1"
    clean_sessions = "ALTER TABLE sessions DELETE WHERE 1"
    Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, clean_events)
    Ecto.Adapters.SQL.query!(Plausible.ClickhouseRepo, clean_sessions)
  end
end
