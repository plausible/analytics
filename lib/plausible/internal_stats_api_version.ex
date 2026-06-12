defmodule Plausible.InternalStatsApiVersion do
  @moduledoc """
  Tracks the effective internal stats API version across the cluster.

  Increment `@api_version` when deploying a change that breaks dashboards
  already loaded from a previous deployment. The FE, upon detecting a
  version mismatch, reloads the page to fetch the new dashboard code.

  Each app node has `@api_version` compiled in. The effective version served
  to clients is the minimum across all connected nodes, fetched via
  `:rpc.multicall` and refreshed every 30 seconds. This means the version
  only advances once every node in a rolling deploy is running the new code,
  avoiding repeated dashboard reloads during the deployment window.
  """
  use GenServer

  @api_version 0

  @refresh_interval :timer.seconds(30)

  @spec api_version() :: non_neg_integer()
  def api_version, do: @api_version

  @spec effective_version() :: non_neg_integer()
  def effective_version() do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    {:ok, @api_version, {:continue, :fetch}}
  end

  @impl GenServer
  def handle_call(:get, _from, version) do
    {:reply, version, version}
  end

  @impl GenServer
  def handle_continue(:fetch, _version) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, fetch_cluster_min()}
  end

  @impl GenServer
  def handle_info(:refresh, _version) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, fetch_cluster_min()}
  end

  defp fetch_cluster_min() do
    {results, _bad_nodes} = :rpc.multicall(__MODULE__, :api_version, [], :timer.seconds(5))
    cluster_min(results)
  end

  def cluster_min(results) do
    case Enum.filter(results, &is_integer/1) do
      [] -> @api_version
      versions -> Enum.min(versions)
    end
  end
end
