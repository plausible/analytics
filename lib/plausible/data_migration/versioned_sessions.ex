defmodule Plausible.DataMigration.VersionedSessions do
  @moduledoc """
  Sessions CollapsingMergeTree -> VersionedCollapsingMergeTree migration, SQL files available at:
  priv/data_migrations/VersionedSessions/sql
  """
  use Plausible.DataMigration, dir: "VersionedSessions", repo: Plausible.IngestRepo

  @suffix_format "{YYYY}{0M}{0D}{h24}{m}{s}"

  def run(opts \\ []) do
    run_exchange? = Keyword.get(opts, :run_exchange?, true)

    unique_suffix = Timex.now() |> Timex.format!(@suffix_format)

    cluster? =
      case run_sql("check-replicas") do
        {:ok, %{num_rows: 0}} -> false
        {:ok, %{num_rows: 1}} -> true
      end

    {:ok, %{rows: partitions}} = run_sql("list-partitions")
    partitions = Enum.map(partitions, fn [part] -> part end)

    {:ok, %{rows: [[table_settings]]}} = run_sql("get-sessions-table-settings")

    run_sql("drop-sessions-tmp-table", cluster?: cluster?)

    run_sql("create-sessions-tmp-table",
      cluster?: cluster?,
      table_settings: table_settings,
      unique_suffix: unique_suffix
    )

    for partition <- partitions do
      run_sql("attach-partition", partition: partition)
    end

    if run_exchange? do
      run_sql("exchange-sessions-tables", cluster?: cluster?)
    end
  end
end
