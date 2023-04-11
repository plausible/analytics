defmodule Mix.Tasks.CleanClickhouse do
  use Mix.Task

  alias Plausible.IngestRepo

  def run(_) do
    %{rows: rows} = IngestRepo.query!("show tables")
    tables = Enum.map(rows, fn [table] -> table end)
    to_truncate = tables -- ["schema_migrations"]

    Enum.each(to_truncate, fn table ->
      IngestRepo.query!("truncate #{table}")
    end)
  end
end
