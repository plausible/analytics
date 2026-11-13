defmodule Plausible.SSRF.Pools do
  @moduledoc """
  One Finch pool per `Plausible.SSRF` request.

  SSRF connects to a checked IP, so the hostname for SNI and certificate checks
  has to be set on the pool. Pools keyed by customer-supplied hostnames would
  pile up, so each request gets its own and stops it when done. The pool is
  linked to the caller, so it also goes away if the caller is killed.
  """

  @finch __MODULE__.Finch

  def child_spec(_opts), do: Finch.child_spec(name: @finch)

  @doc """
  Starts a pool for one request, calls `fun` with the `:finch` options pointing
  at it, then stops the pool. `cacerts` of `nil` means the system store.
  """
  @spec with_pool(URI.t(), String.t(), :inet.ip_address(), [binary()] | nil, (keyword() -> r)) ::
          r
        when r: term()
  def with_pool(%URI{} = pinned_url, host, ip, cacerts, fun) do
    pool = %Finch.Pool{
      scheme: :https,
      host: pinned_url.host,
      port: pinned_url.port,
      tag: {host, make_ref()}
    }

    spec =
      Finch.Pool.child_spec(
        finch: @finch,
        pool: pool,
        conn_opts: [hostname: host, transport_opts: transport_opts(ip, cacerts)]
      )

    {:ok, supervisor} = Supervisor.start_link([spec], strategy: :one_for_one)

    try do
      fun.(name: @finch, pool_tag: pool.tag)
    after
      stop(supervisor)
    end
  end

  # Mint verifies the certificate against `hostname` by default.
  defp transport_opts(ip, cacerts) do
    [inet6: tuple_size(ip) == 8] ++ if(cacerts, do: [cacerts: cacerts], else: [])
  end

  # The pool may already be gone; don't lose the response over it.
  defp stop(supervisor) do
    Supervisor.stop(supervisor)
  catch
    :exit, _ -> :ok
  end
end
