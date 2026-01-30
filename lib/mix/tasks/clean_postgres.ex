defmodule Mix.Tasks.CleanPostgres do
  @moduledoc false

  use Mix.Task

  alias Plausible.Repo

  def run(_) do
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
  end
end
