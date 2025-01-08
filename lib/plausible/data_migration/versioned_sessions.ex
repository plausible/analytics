defmodule Plausible.DataMigration.VersionedSessions do
  @moduledoc """
  !!!WARNING!!!: This script is used in migrations. Please take special care
  when altering it.

  Sessions CollapsingMergeTree -> VersionedCollapsingMergeTree migration,
  SQL files available at:

  priv/data_migrations/VersionedSessions/sql
  """
  use Plausible.DataMigration, dir: "VersionedSessions", repo: Plausible.IngestRepo

  @suffix_format "{YYYY}{0M}{0D}{h24}{m}{s}"
  @versioned_table_engines [
    "ReplicatedVersionedCollapsingMergeTree",
    "VersionedCollapsingMergeTree"
  ]

  def run(opts \\ []) do
    run_exchange? = Keyword.get(opts, :run_exchange?, true)

    unique_suffix = Timex.now() |> Timex.format!(@suffix_format)

    cluster? = Plausible.MigrationUtils.cluster_name()

    cluster_name =
      if cluster? do
        Plausible.MigrationUtils.cluster_name()
      else
        nil
      end

    {:ok, %{rows: partitions}} = run_sql("list-partitions")
    partitions = Enum.map(partitions, fn [part] -> part end)

    {:ok, %{rows: [[current_table_engine, table_settings]]}} =
      run_sql("get-sessions-table-settings")

    if Enum.member?(@versioned_table_engines, current_table_engine) do
      IO.puts("sessions_v2 table is already versioned, no migration needed")
    else
      {:ok, _} =
        run_sql("drop-sessions-tmp-table", cluster?: cluster?, cluster_name: cluster_name)

      {:ok, _} =
        run_sql("create-sessions-tmp-table",
          cluster?: cluster?,
          cluster_name: cluster_name,
          table_settings: table_settings,
          unique_suffix: unique_suffix
        )

      for partition <- partitions do
        {:ok, _} = run_sql("attach-partition", partition: partition)
      end

      if run_exchange? do
        run_exchange(cluster?, cluster_name)
      end

      IO.puts("Migration done!")
    end
  end

  defp run_exchange(cluster?, cluster_name) do
    case run_sql("exchange-sessions-tables", cluster?: cluster?, cluster_name: cluster_name) do
      {:ok, _} ->
        nil

      # Docker containers don't seem to support EXCHANGE TABLE, hack around this with a non-atomic swap
      {:error, %Ch.Error{code: code}} when code in [1, 48] ->
        IO.puts("Exchanging sessions_v2 and sessions_v2_tmp_versioned non-atomically")

        {:ok, _} =
          run_sql("rename-table",
            from: "sessions_v2",
            to: "sessions_v2_backup",
            cluster?: cluster?,
            cluster_name: cluster_name
          )

        {:ok, _} =
          run_sql("rename-table",
            from: "sessions_v2_tmp_versioned",
            to: "sessions_v2",
            cluster?: cluster?,
            cluster_name: cluster_name
          )
    end
  end
end
