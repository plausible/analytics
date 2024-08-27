defmodule Plausible.MigrationUtils do
  @moduledoc """
  Base module for to use in Clickhouse migrations
  """

  alias Plausible.IngestRepo

  def on_cluster_statement(table) do
    if(IngestRepo.clustered_table?(table), do: "ON CLUSTER '{cluster}'", else: "")
  end

  # See https://clickhouse.com/docs/en/sql-reference/dictionaries#clickhouse for context
  def dictionary_connection_params() do
    IngestRepo.config()
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
