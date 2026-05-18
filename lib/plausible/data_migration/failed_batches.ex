defmodule Plausible.DataMigration.FailedBatches do
  @moduledoc """
  ClickHouse failed batches data migration for storing failed batches in ClickHouse.
  """

  use Plausible.DataMigration, dir: "FailedBatches", repo: Plausible.IngestRepo

  def run do
    cluster? = Plausible.IngestRepo.clustered_table?("sessions_v2")

    {:ok, _} =
      run_sql("create-failed-batches-table",
        cluster?: cluster?,
        table_settings: Plausible.MigrationUtils.table_settings_expr(:prefix)
      )

    {:ok, _} =
      run_sql("create-failed-batches-dictionary",
        cluster?: cluster?,
        dictionary_connection_params: Plausible.MigrationUtils.dictionary_connection_params()
      )
  end
end
