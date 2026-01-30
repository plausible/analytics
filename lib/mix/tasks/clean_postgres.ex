defmodule Mix.Tasks.CleanPostgres do
  @moduledoc false

  use Mix.Task

  alias Plausible.Repo

  def run(_) do
    case Plausible.Repo.start_link(pool_size: 1, log: false) do
      {:ok, _} -> :pass
      {:error, {:already_started, _pid}} -> :pass
      {:error, _} = error -> throw(error)
    end

    query = """
    SELECT tablename
    FROM pg_catalog.pg_tables
    WHERE schemaname != 'pg_catalog' AND
        schemaname != 'information_schema';
    """

    %{rows: rows} = Repo.query!(query)
    tables = Enum.map(rows, fn [table] -> table end)

    Enum.each(tables -- ["schema_migrations"], fn table ->
      Repo.query!("truncate #{table} cascade")
    end)
  after
    Plausible.Repo.stop(500)
  end
end
