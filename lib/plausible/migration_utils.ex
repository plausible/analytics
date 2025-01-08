defmodule Plausible.MigrationUtils do
  @moduledoc """
  Base module for to use in Clickhouse migrations
  """

  def on_cluster_statement(_table) do
    case cluster_name() do
      {:ok, cluster} -> "ON CLUSTER '#{cluster}'"
      _ -> ""
    end
  end

  def cluster_name do
    try do
      case Plausible.IngestRepo.query(
             "SELECT cluster FROM system.clusters where cluster = '#{Plausible.IngestRepo.config()[:database]}' limit 1;"
           ) do
        {:ok, %{rows: [[cluster]]}} -> cluster
        {:ok, _} -> false
        {:error, _} -> false
      end
    rescue
      _ -> false
    end
  end
end
