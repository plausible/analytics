defmodule Mix.Tasks.CleanClickhouse do
  use Mix.Task

  alias Plausible.IngestRepo

  def run(_) do
    %{rows: rows} = IngestRepo.query!("show tables")
    tables = Enum.map(rows, fn [table] -> table end)

    to_truncate =
      tables --
        [
          "schema_migrations",
          "location_data",
          "location_data_dict",
          "acquisition_channel_source_category",
          "acquisition_channel_source_category_dict",
          "acquisition_channel_paid_sources",
          "acquisition_channel_paid_sources_dict"
        ]

    Enum.each(to_truncate, fn table ->
      IngestRepo.query!("truncate #{table}")
    end)
  end
end
