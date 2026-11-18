defmodule Plausible.SSRF.Pools do
  @moduledoc """
  Finch pools for `Plausible.SSRF` requests.

  SSRF connects to a checked IP, so the hostname for SNI and certificate checks
  has to be set on the pool. Each address and hostname gets a pool of its own,
  which Finch stops once it has been idle for `@max_idle_time`.
  """

  @finch __MODULE__.Finch
  @max_idle_time Application.compile_env(
                   :plausible,
                   [__MODULE__, :max_idle_time],
                   :timer.seconds(10)
                 )
  @connect_timeout :timer.seconds(5)

  # Requests only reach a pool started below. Should one ever be started from
  # the default config, it also stops when idle.
  def child_spec(_opts) do
    Finch.child_spec(name: @finch, pools: %{default: [pool_max_idle_time: @max_idle_time]})
  end

  @doc """
  Starts the pool for `host` at the pinned address, unless it's already
  running, and returns the `:finch` options pointing at it. `cacerts` of `nil`
  means the system store.
  """
  @spec finch_opts(URI.t(), String.t(), :inet.ip_address(), [binary()] | nil) :: keyword()
  def finch_opts(%URI{} = pinned_url, host, ip, cacerts) do
    pool = %Finch.Pool{scheme: :https, host: pinned_url.host, port: pinned_url.port, tag: host}

    :ok =
      Finch.start_pool(@finch, pool,
        conn_opts: [hostname: host, transport_opts: transport_opts(ip, cacerts)],
        pool_max_idle_time: @max_idle_time
      )

    [name: @finch, pool_tag: pool.tag]
  end

  # Mint verifies the certificate against `hostname` by default.
  defp transport_opts(ip, cacerts) do
    [inet6: tuple_size(ip) == 8, timeout: @connect_timeout] ++
      if(cacerts, do: [cacerts: cacerts], else: [])
  end
end
