defmodule Plausible.DataMigration.AcquisitionChannel do
  @moduledoc """
  Creates dictionaries and functions to calculate acquisition channel in ClickHouse

  SQL files available at: priv/data_migrations/AcquisitionChannel/sql
  """
  use Plausible.DataMigration, dir: "AcquisitionChannel", repo: Plausible.IngestRepo

  def run(opts \\ []) do
    on_cluster_statement = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")

    run_sql_multi(
      "acquisition_channel_functions",
      [
        on_cluster_statement: on_cluster_statement,
        dictionary_connection_params: Plausible.MigrationUtils.dictionary_connection_params()
      ],
      params: %{
        "source_categories" =>
          Plausible.Ingestion.Acquisition.source_categories() |> Map.to_list(),
        "paid_sources" => Plausible.Ingestion.Source.paid_sources()
      },
      quiet: Keyword.get(opts, :quiet, false)
    )
  end
end
