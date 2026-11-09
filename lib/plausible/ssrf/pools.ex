defmodule Plausible.SSRF.Pools do
  @moduledoc """
  Finch pools for `Plausible.SSRF`, keyed so repeat requests reuse a connection.

  SSRF connects to a checked IP, so the hostname for SNI and certificate checks
  has to be set on the pool, not read from the connection address. The pool key
  is `{scheme, ip, port, host}`: the same host on the same IP and port reuse one
  pool; a host that moves to another IP, or a different host on the same IP, gets
  its own. Idle pools shut themselves down, so customer-supplied hostnames don't
  pile up.
  """

  use Supervisor

  @finch __MODULE__.Finch
  @pool_sup __MODULE__.PoolSupervisor
  @task_sup __MODULE__.TaskSupervisor
  @pool_max_idle_time :timer.seconds(10)

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Finch, name: @finch},
      {DynamicSupervisor, name: @pool_sup, strategy: :one_for_one},
      {Task.Supervisor, name: @task_sup}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Supervisor for the unlinked tasks that run SSRF requests."
  def task_supervisor, do: @task_sup

  @doc """
  Ensures the pool for `{host, ip, port}` is started, then calls `fun` with
  `:finch` options pointing at it. `cacerts` of `nil` means the system store.
  The pool stays idle for #{@pool_max_idle_time} ms and shuts down.
  """
  @spec with_pool(URI.t(), String.t(), :inet.ip_address(), [binary()] | nil, (keyword() -> r)) ::
          r
        when r: term()
  def with_pool(%URI{} = pinned_url, host, ip, cacerts, fun) do
    pool = %Finch.Pool{
      scheme: :https,
      host: pinned_url.host,
      port: pinned_url.port,
      tag: host
    }

    spec =
      Finch.Pool.child_spec(
        finch: @finch,
        pool: pool,
        pool_max_idle_time: @pool_max_idle_time,
        conn_opts: [hostname: host, transport_opts: transport_opts(ip, cacerts)]
      )

    case DynamicSupervisor.start_child(@pool_sup, spec) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    fun.(name: @finch, pool_tag: pool.tag)
  end

  # Mint verifies the certificate against `hostname` by default.
  defp transport_opts(ip, cacerts) do
    [inet6: tuple_size(ip) == 8] ++ if(cacerts, do: [cacerts: cacerts], else: [])
  end
end
