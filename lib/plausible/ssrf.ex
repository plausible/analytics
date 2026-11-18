defmodule Plausible.SSRF do
  @moduledoc """
  Guards outbound HTTP requests and DNS lookups against customer-supplied
  hostnames reaching internal, private or local network space
  """

  @type error_reason ::
          :invalid_url
          | :invalid_host
          | :dns_resolution_failed
          | :restricted_address
          | :redirect_not_followed

  @redirect_statuses [301, 302, 303, 307, 308]
  @default_receive_timeout :timer.seconds(5)
  @default_request_timeout :timer.seconds(5)
  @default_max_retries 2
  @default_retry_delay :timer.seconds(1)
  @dns_timeout 1_000
  @connect_timeout :timer.seconds(5)
  @finch __MODULE__.Finch
  @pool_max_idle_time :timer.seconds(10)

  # Swappable for tests
  @ip_check Application.compile_env(:plausible, :ssrf_ip_check, Plausible.IP.Tools)

  def child_spec(_opts) do
    # Workaround. An idle pool lingers for a 1s grace period, then stops. A request landing
    # just as it stops gets a replacement from these defaults, without our other options.
    # This closes it ASAP, which is 1ms idle + 1s grace period without requests.
    default_opts = [pool_max_idle_time: 1]
    Finch.child_spec(name: @finch, pools: %{default: default_opts})
  end

  @doc """
  Resolves bare hostname or literal IP and returns its address(es),
  only if all are allowed
  """
  @spec resolve_host(String.t()) :: {:ok, [:inet.ip_address()]} | {:error, error_reason()}
  def resolve_host(host) when is_binary(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, ip} ->
        validate_ips([ip])

      {:error, :einval} ->
        if String.contains?(host, ".") do
          host |> dns_lookup() |> validate_ips()
        else
          {:error, :invalid_host}
        end
    end
  end

  @doc """
  Performs a GET request against arbitrary URL, refusing to connect to a
  restricted address.

  Does not follow redirects: a redirect is `{:error, :redirect_not_followed}`.

  Retries transient failures twice, a second apart.

  Each attempt has 5s to connect and `:request_timeout` ms to respond, which
  can overrun by up to `:receive_timeout`.

  Provide the option `:cacerts` when testing against mock https server. It replaces the system CA store.
  """
  @spec get(String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, error_reason() | Exception.t()}
  def get(url, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:retry, :safe_transient)
      |> Keyword.put_new(:max_retries, @default_max_retries)
      # needed, so Req would ignore the response header Retry-After
      |> Keyword.put_new(:retry_delay, @default_retry_delay)
      |> Keyword.put_new(:retry_log_level, false)
      |> Keyword.put_new(:receive_timeout, @default_receive_timeout)
      |> Keyword.put_new(:request_timeout, @default_request_timeout)
      # Req still honours it as an alias of :redirect, and it wins.
      |> Keyword.delete(:follow_redirects)

    with {:ok, uri} <- parse_url(url),
         {:ok, ips} <- resolve_host(uri.host),
         {:ok, resp} <- do_request(uri, hd(ips), opts) do
      handle_response(resp)
    end
  end

  # HTTPS only: the certificate is the only proof the right
  # host answered.
  defp parse_url(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: host} = uri} when is_binary(host) and host != "" ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url}
    end
  end

  # Connects to the checked IP, not the hostname, so DNS can't change in between.
  defp do_request(uri, ip, opts) do
    host = uri.host
    pinned_url = %{uri | host: ip |> :inet.ntoa() |> to_string()}
    {cacerts, opts} = Keyword.pop(opts, :cacerts)

    opts
    |> Keyword.merge(
      method: :get,
      url: pinned_url,
      headers: [{"host", host}],
      finch: finch_opts(pinned_url, host, ip, cacerts),
      redirect: false
    )
    |> Req.request()
  end

  # One pool per IP and hostname, carrying the hostname for the certificate
  # check. Idle pools stop on their own.
  defp finch_opts(pinned_url, host, ip, cacerts) do
    pool = %Finch.Pool{scheme: :https, host: pinned_url.host, port: pinned_url.port, tag: host}

    :ok =
      Finch.start_pool(@finch, pool,
        conn_opts: [hostname: host, transport_opts: transport_opts(ip, cacerts)],
        pool_max_idle_time: @pool_max_idle_time
      )

    [name: @finch, pool_tag: pool.tag]
  end

  # Mint verifies the certificate against `hostname` by default.
  # `cacerts` of `nil` means the system store.
  defp transport_opts(ip, cacerts) do
    [inet6: tuple_size(ip) == 8, timeout: @connect_timeout] ++
      if(cacerts, do: [cacerts: cacerts], else: [])
  end

  defp handle_response(%Req.Response{status: status} = resp)
       when status in @redirect_statuses do
    case Req.Response.get_header(resp, "location") do
      [_ | _] -> {:error, :redirect_not_followed}
      [] -> {:ok, resp}
    end
  end

  defp handle_response(resp), do: {:ok, resp}

  defp dns_lookup(host) do
    charlist_host = to_charlist(host)
    opts = [timeout: @dns_timeout]

    a = Plausible.DnsLookup.impl().lookup(charlist_host, :in, :a, opts, @dns_timeout)
    aaaa = Plausible.DnsLookup.impl().lookup(charlist_host, :in, :aaaa, opts, @dns_timeout)

    a ++ aaaa
  end

  defp validate_ips([]) do
    {:error, :dns_resolution_failed}
  end

  defp validate_ips(ips) do
    if Enum.all?(ips, &@ip_check.allowed?(&1)) do
      {:ok, ips}
    else
      {:error, :restricted_address}
    end
  end
end
