defmodule Plausible.DataMigration.AcquisitionChannel do
  @moduledoc """
  Creates dictionaries and functions to calculate acquisition channel in ClickHouse

  Creates `acquisition_channel` columns in `events_v2` and `sessions_v2` tables.
  Run via `Plausible.DataMigration.AcquisitionChannel.run(options)`

  Options:
  - `add_column` - creates the materialized column. Already done in a migration
  - `update_column` - Updates the column definition to use new function definitions. Defaults to true.
      Note that historical data is only updated if `backfill` is set to true or if it was never materialized.
  - `backfill` - backfills the data for the column. Speeds up calculations on historical data.

  SQL files available at: priv/data_migrations/AcquisitionChannel/sql
  """
  use Plausible.DataMigration, dir: "AcquisitionChannel", repo: Plausible.IngestRepo

  def run(opts \\ []) do
    on_cluster_statement = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")
    # In distributed environments, wait for insert to all temporary tables.
    insert_quorum = Plausible.IngestRepo.replica_count("sessions_v2")

    :ok =
      run_sql_multi(
        "acquisition_channel_functions",
        [
          on_cluster_statement: on_cluster_statement,
          table_settings: Plausible.MigrationUtils.table_settings_expr(),
          dictionary_connection_params: Plausible.MigrationUtils.dictionary_connection_params(),
          insert_quorum: insert_quorum
        ],
        params: %{
          "source_categories" =>
            Plausible.Ingestion.Acquisition.source_categories() |> Map.to_list(),
          "paid_sources" => Plausible.Ingestion.Source.paid_sources()
        },
        quiet: Keyword.get(opts, :quiet, false)
      )

    cond do
      Keyword.get(opts, :add_column) ->
        alter_data_tables(
          "acquisition_channel_add_materialized_column",
          on_cluster_statement,
          opts
        )

      Keyword.get(opts, :update_column, true) ->
        alter_data_tables(
          "acquisition_channel_update_materialized_column",
          on_cluster_statement,
          opts
        )

      true ->
        nil
    end

    if Keyword.get(opts, :backfill) do
      alter_data_tables(
        "acquisition_channel_backfill_materialized_column",
        on_cluster_statement,
        opts
      )
    end

    :ok
  end

  defp alter_data_tables(sql_name, on_cluster_statement, opts) do
    {:ok, _} =
      run_sql(
        sql_name,
        [
          table: "events_v2",
          on_cluster_statement: on_cluster_statement
        ],
        quiet: Keyword.get(opts, :quiet, false)
      )

    {:ok, _} =
      run_sql(
        sql_name,
        [
          table: "sessions_v2",
          on_cluster_statement: on_cluster_statement
        ],
        quiet: Keyword.get(opts, :quiet, false)
      )
  end
end
