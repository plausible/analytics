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
end
