defmodule Plausible.MigrationUtils do
  @moduledoc """
  Base module for to use in Clickhouse migrations
  """

  def on_cluster_statement(table) do
    if(clustered_table?(table), do: "ON CLUSTER '{cluster}'", else: "")
  end

  def clustered_table?(table) do
    case Plausible.IngestRepo.query("SELECT 1 FROM system.replicas WHERE table = '#{table}'") do
      {:ok, %{rows: []}} -> false
      {:ok, _} -> true
    end
  end

  # See https://clickhouse.com/docs/en/sql-reference/dictionaries#clickhouse for context
  def dictionary_connection_params() do
    Plausible.IngestRepo.config()
    |> Enum.map(fn
      {:database, database} -> "DB '#{database}'"
      {:username, username} -> "USER '#{username}'"
      {:password, password} -> "PASSWORD '#{password}'"
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end
end
