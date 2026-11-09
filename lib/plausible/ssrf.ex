defmodule Plausible.SSRF do
  @moduledoc """
  Guards outbound HTTP requests and DNS lookups against customer-supplied
  hostnames reaching internal, private or local network space
  """

  alias Plausible.SSRF.Pools

  @type error_reason ::
          :invalid_url
          | :invalid_host
          | :dns_resolution_failed
          | :restricted_address
          | :redirect_not_followed
          | :timeout
          | :request_failed

  @redirect_statuses [301, 302, 303, 307, 308]
  @default_receive_timeout :timer.seconds(5)
  @default_total_timeout :timer.seconds(30)
  @default_max_retries 2
  @default_retry_delay :timer.seconds(1)
  @dns_timeout 1_000

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

  The whole call is cut off after `:total_timeout` ms.

  Provide the option `:cacerts` when testing against mock https server. It replaces the system CA store.
  """
  @spec get(String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, error_reason() | Exception.t()}
  def get(url, opts \\ []) do
    {total_timeout, opts} = Keyword.pop(opts, :total_timeout, @default_total_timeout)

    opts =
      opts
      |> Keyword.put_new(:retry, :safe_transient)
      |> Keyword.put_new(:max_retries, @default_max_retries)
      # needed, so Req would ignore the response header Retry-After
      |> Keyword.put_new(:retry_delay, @default_retry_delay)
      |> Keyword.put_new(:retry_log_level, false)
      |> Keyword.put_new(:receive_timeout, @default_receive_timeout)
      # Req still honours it as an alias of :redirect, and it wins.
      |> Keyword.delete(:follow_redirects)

    # Make sure that Req exceptions are returned
    task = Task.Supervisor.async_nolink(Pools.task_supervisor(), fn -> request(url, opts) end)

    case Task.yield(task, total_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, {exception, _stacktrace}} when is_exception(exception) -> {:error, exception}
      {:exit, _reason} -> {:error, :request_failed}
      nil -> {:error, :timeout}
    end
  end

  defp request(url, opts) do
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
  # Never pass the hostname as `:connect_options`: Req starts a Finch instance per
  # distinct value and never stops them.
  defp do_request(uri, ip, opts) do
    host = uri.host
    pinned_url = %{uri | host: ip |> :inet.ntoa() |> to_string()}
    {cacerts, opts} = Keyword.pop(opts, :cacerts)

    Pools.with_pool(pinned_url, host, ip, cacerts, fn finch ->
      opts
      |> Keyword.merge(
        method: :get,
        url: pinned_url,
        headers: [{"host", host}],
        finch: finch,
        redirect: false
      )
      |> Req.request()
    end)
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
    # Swappable so tests can allow their own loopback server.
    check = Application.get_env(:plausible, :ssrf_ip_check) || Plausible.IP.Tools

    if Enum.all?(ips, &check.allowed?(&1)) do
      {:ok, ips}
    else
      {:error, :restricted_address}
    end
  end
end
