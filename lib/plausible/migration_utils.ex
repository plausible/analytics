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

  def table_settings() do
    IngestRepo.config()
    |> Keyword.get(:table_settings)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def table_settings_expr(type \\ :prefix) do
    expr = Enum.map_join(table_settings(), ", ", fn {k, v} -> "#{k} = #{encode(v)}" end)

    case {table_settings(), type} do
      {[], _} -> ""
      {_, :prefix} -> "SETTINGS #{expr}"
      {_, :suffix} -> ", #{expr}"
    end
  end

  defp encode(value) when is_number(value), do: value
  defp encode(value) when is_binary(value), do: "'#{value}'"
end
