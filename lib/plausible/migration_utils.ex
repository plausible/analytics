defmodule Plausible.MigrationUtils do
  @moduledoc """
  Base module for to use in Clickhouse migrations
  """

  def on_cluster_statement(table) do
    case Plausible.IngestRepo.query("SELECT 1 FROM system.replicas WHERE table = '#{table}'") do
      {:ok, %{rows: []}} -> ""
      {:ok, _} -> "ON CLUSTER '{cluster}'"
    end
  end
end
