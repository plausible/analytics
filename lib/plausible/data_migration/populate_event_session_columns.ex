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

  def run(opts \\ []) do
    cluster? = Plausible.MigrationUtils.clustered_table?("sessions_v2")

    {:ok, _} =
      run_sql("create-sessions-dictionary",
        cluster?: cluster?,
        dictionary_connection_params: get_dictionary_connection_params(opts)
      )

    {partitions, _, _, _} = get_partitions(opts)

    Logger.info("Starting mutation on #{length(partitions)} partition(s)")

    for partition <- partitions do
      # TODO: Update column names once other PRs are in.
      {:ok, _} = run_sql("update-table", cluster?: cluster?, partition: partition)
    end

    wait_until_mutations_complete(opts)

    Logger.info("Mutations seem done, cleaning up!")
    {:ok, _} = run_sql("drop-sessions-dictionary", cluster?: cluster?)
  end

  def kill(opts \\ []) do
    cluster? = Plausible.MigrationUtils.clustered_table?("events_v2")

    report_progress(opts)

    Logger.info("Killing running mutations")
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

    [[mutations, parts_to_do, running_for, total_size, todo_size, progress, _, _]] =
      mutation_results

    {:ok, %{rows: [[merges]]}} = run_sql("get-merges-progress")
    {:ok, %{rows: disks}} = run_sql("get-disks")

    # List partitions that need to run
    Logger.info(
      "Progress report for partitions #{Enum.min(partitions)}-#{Enum.max(partitions)} (parts: #{length(parts)})"
    )

    Logger.info("Disks overview:")

    for [name, path, full_space, total_space, full_percentage] <- disks do
      Logger.info(
        "  #{name} at #{path} is at #{full_space}/#{total_space} (#{full_percentage}% full)"
      )
    end

    Logger.info("Currently #{mutations} mutation(s) are running.")

    if mutations > 0 do
      Logger.info("  To do #{parts_to_do} parts, #{todo_size}")
      Logger.info("  Out of #{length(parts)} parts, #{total_size}")
      Logger.info("  Running for #{format_duration(running_for)}")

      if progress > 0 do
        estimated_time_left = running_for / progress / 100 - running_for
        Logger.info("  Estimated #{progress}% done, #{format_duration(estimated_time_left)} left")
      end
    end

    Logger.info("Currently #{merges} merge(s) are running relating to mutations.")

    mutations > 0
  end

  # See https://clickhouse.com/docs/en/sql-reference/dictionaries#clickhouse for context
  def get_dictionary_connection_params(opts \\ []) do
    connection_params = Keyword.get(opts, :dictionary_connection_string)

    if connection_params do
    else
      uri =
        Application.get_env(:plausible, Plausible.IngestRepo) |> Keyword.get(:url) |> URI.parse()

      database = String.trim(uri.path, "/")

      if uri.userinfo do
        [username, password] =
          if uri.userinfo, do: String.split(uri.userinfo, ":"), else: [nil, nil]

        "USER '#{username}' PASSWORD '#{password}' DB '#{database}'"
      else
        "DB '#{database}'"
      end
    end
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
