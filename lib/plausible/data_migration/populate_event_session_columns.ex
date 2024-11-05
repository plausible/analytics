defmodule Plausible.DataMigration.PopulateEventSessionColumns do
  @moduledoc """
  Populates event session columns with data from sessions table.

  Run via: ./bin/plausible rpc "Plausible.DataMigration.PopulateEventSessionColumns.run"
  Kill via: ./bin/plausible rpc "Plausible.DataMigration.PopulateEventSessionColumns.kill"
  Monitor via ./bin/plausible rpc "Plausible.DataMigration.PopulateEventSessionColumns.report_progress"

  Suggested to run in a screen/tmux session to be able to easily monitor

  SQL files available at: priv/data_migrations/PopulateEventSessionColumns/sql
  """
  use Plausible.DataMigration, dir: "PopulateEventSessionColumns", repo: Plausible.IngestRepo

  require Logger

  # See https://clickhouse.com/docs/en/sql-reference/dictionaries#cache for meaning of these defaults
  @default_dictionary_config %{
    lifetime: 600_000,
    size_in_cells: 1_000_000,
    max_threads_for_updates: 6
  }

  def run(opts \\ []) do
    cluster? = Plausible.IngestRepo.clustered_table?("sessions_v2")

    {:ok, _} =
      run_sql("create-sessions-dictionary",
        cluster?: cluster?,
        dictionary_connection_params:
          Keyword.get(
            opts,
            :dictionary_connection_string,
            Plausible.MigrationUtils.dictionary_connection_params()
          ),
        dictionary_config: dictionary_config(opts)
      )

    {partitions, _, _, _} = get_partitions(opts)

    IO.puts("Starting mutation on #{length(partitions)} partition(s)")

    for partition <- partitions do
      {:ok, _} =
        run_sql("update-table", [cluster?: cluster?, partition: partition],
          query_options: [settings: [allow_nondeterministic_mutations: 1]]
        )
    end

    wait_until_mutations_complete(opts)

    IO.puts("Mutations seem done, cleaning up!")
    {:ok, _} = run_sql("drop-sessions-dictionary", cluster?: cluster?)
  end

  def kill(opts \\ []) do
    cluster? = Plausible.IngestRepo.clustered_table?("events_v2")

    report_progress(opts)

    IO.puts("Killing running mutations")
    {:ok, _} = run_sql("kill-running-mutations", cluster?: cluster?)
  end

  def wait_until_mutations_complete(opts \\ []) do
    Process.sleep(5_000)
    in_progress? = report_progress(opts)

    if in_progress? do
      wait_until_mutations_complete(opts)
    end
  end

  def report_progress(opts \\ []) do
    {partitions, parts, min_partition, max_partition} = get_partitions(opts)

    {:ok, %{rows: mutation_results}} =
      run_sql("get-mutations-progress",
        min_partition: min_partition,
        max_partition: max_partition
      )

    [
      [
        mutations,
        parts_to_do,
        running_for,
        total_size,
        todo_size,
        progress,
        latest_fail_reason,
        _,
        _
      ]
    ] =
      mutation_results

    {:ok, %{rows: [[merges]]}} = run_sql("get-merges-progress")
    {:ok, %{rows: disks}} = run_sql("get-disks")

    IO.puts("\n\n#{DateTime.utc_now() |> DateTime.to_iso8601()}")

    # List partitions that need to run
    IO.puts(
      "Progress report for partitions #{Enum.min(partitions)}-#{Enum.max(partitions)} (parts: #{length(parts)})"
    )

    IO.puts("Disks overview:")

    for [name, path, full_space, total_space, full_percentage] <- disks do
      IO.puts(
        "  #{name} at #{path} is at #{full_space}/#{total_space} (#{full_percentage}% full)"
      )
    end

    IO.puts("Currently #{mutations} mutation(s) are running.")

    if mutations > 0 do
      IO.puts("  To do #{parts_to_do} parts, #{todo_size}")
      IO.puts("  Out of #{length(parts)} parts, #{total_size}")
      IO.puts("  Running for #{format_duration(running_for)}")

      if progress > 0 do
        estimated_time_left = round(running_for / progress / 100 - running_for)
        IO.puts("  Estimated #{progress}% done, #{format_duration(estimated_time_left)} left")
      end

      if latest_fail_reason do
        IO.puts("  Some mutations might be failing. ClickHouse report: #{latest_fail_reason}")
      end
    end

    IO.puts("Currently #{merges} merge(s) are running relating to mutations.")

    mutations > 0
  end

  defp dictionary_config(opts) do
    @default_dictionary_config
    |> Map.merge(Keyword.get(opts, :dictionary_config, %{}))
  end

  defp get_partitions(opts) do
    [min_partition, max_partition] = Keyword.get(opts, :partition_range, ["0", "999999"])

    {:ok, %{rows: [[partitions, parts]]}} =
      run_sql("list-partitions", min_partition: min_partition, max_partition: max_partition)

    {partitions, parts, min_partition, max_partition}
  end

  defp format_duration(seconds) do
    seconds
    |> Timex.Duration.from_seconds()
    |> Timex.format_duration(Timex.Format.Duration.Formatters.Humanized)
  end
end
