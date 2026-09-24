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

  @api_version 1

  @refresh_interval :timer.seconds(30)

  @spec api_version() :: non_neg_integer()
  def api_version, do: @api_version

  @spec effective_version() :: non_neg_integer()
  def effective_version() do
    # Use 0 as a placeholder version until the first multicall completes.
    # The FE only reloads when the received version exceeds its compiled-in
    # expectation, so 0 is always safe regardless of current @api_version.
    case :ets.lookup(__MODULE__, :version) do
      [{:version, v}] -> v
      _ -> 0
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    __MODULE__ =
      :ets.new(__MODULE__, [
        :named_table,
        :set,
        :protected,
        {:read_concurrency, true}
      ])

    {:ok, nil, {:continue, :fetch}}
  end

  @impl GenServer
  def handle_continue(:fetch, state) do
    Process.send_after(self(), :refresh, @refresh_interval)
    :ets.insert(__MODULE__, {:version, fetch_cluster_min()})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    Process.send_after(self(), :refresh, @refresh_interval)
    :ets.insert(__MODULE__, {:version, fetch_cluster_min()})
    {:noreply, state}
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
