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
end
