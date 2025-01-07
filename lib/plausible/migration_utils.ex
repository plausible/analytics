defmodule Plausible.MigrationUtils do
  @moduledoc """
  Base module for to use in Clickhouse migrations
  """

  def on_cluster_statement(table) do
    if(clustered_table?(table), do: "ON CLUSTER '#{cluster_name()}'", else: "")
  end

  def clustered_table?(table) do
    case Plausible.IngestRepo.query("SELECT 1 FROM system.replicas WHERE table = '#{table}'") do
      {:ok, %{rows: []}} -> false
      {:ok, _} -> true
    end
  end

  def cluster_name do
    case Plausible.IngestRepo.query(
           "SELECT cluster FROM system.clusters where cluster = '#{Plausible.IngestRepo.config()[:database]}' limit 1;"
         ) do
      {:ok, %{rows: [[cluster]]}} -> cluster
      {:ok, _} -> raise "No cluster defined."
      {:error, _} -> raise "Cluster not found"
    end
  end
end
