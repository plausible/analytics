defmodule Mix.Tasks.CleanClickhouse do
  @moduledoc false

  use Mix.Task

  alias Plausible.IngestRepo

  def run(_) do
    case Plausible.IngestRepo.start_link(pool_size: 1, log: false) do
      {:ok, _} -> :pass
      {:error, {:already_started, _pid}} -> :pass
      {:error, _} = error -> throw(error)
    end

    %{rows: rows} = IngestRepo.query!("show tables")
    tables = Enum.map(rows, fn [table] -> table end)

    to_truncate =
      tables --
        [
          "schema_migrations",
          "failed_batches",
          "failed_batches_dict",
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
  after
    Plausible.IngestRepo.stop(500)
  end
end
