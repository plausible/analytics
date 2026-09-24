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
          | :too_many_redirects

  @redirect_statuses [301, 302, 303, 307, 308]
  @default_max_redirects 4
  @dns_timeout 1_000

  # Every distinct `connect_options: [hostname: ...]` value we pass below
  # makes Req start a brand new, dedicated Finch instance under the hood
  # (Req can't vary `conn_opts` per-request on a shared pool, so it forks one
  # per connect_options fingerprint) - and since these hostnames are
  # customer-controlled, that's an unbounded number of them over time. 
  @default_pool_max_idle_time :timer.minutes(5)

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
  Performs a GET request against arbitrary URL, refusing to connect to (or be
  redirected to) a restricted address
  """
  @spec get(String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, error_reason() | Exception.t()}
  def get(url, opts \\ []) do
    max_redirects = Keyword.get(opts, :max_redirects, @default_max_redirects)
    request(url, opts, max_redirects)
  end

  defp request(url, opts, redirects_left) do
    with {:ok, uri} <- parse_url(url),
         {:ok, ips} <- resolve_host(uri.host),
         {:ok, resp} <- do_request(uri, hd(ips), opts) do
      handle_response(resp, uri, opts, redirects_left)
    end
  end

  defp parse_url(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host} = uri}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp do_request(uri, ip, opts) do
    host = uri.host
    pinned_url = %{uri | host: ip |> :inet.ntoa() |> to_string()}

    request_opts =
      opts
      |> Keyword.put_new(:pool_max_idle_time, @default_pool_max_idle_time)
      |> Keyword.merge(
        method: :get,
        url: pinned_url,
        headers: [{"host", host}],
        connect_options: [hostname: host],
        redirect: false
      )

    Req.request(request_opts)
  end

  defp handle_response(%Req.Response{status: status} = resp, uri, opts, redirects_left)
       when status in @redirect_statuses do
    case Req.Response.get_header(resp, "location") do
      [location | _] when redirects_left > 0 ->
        next_url = uri |> URI.merge(location) |> URI.to_string()
        request(next_url, opts, redirects_left - 1)

      [_ | _] ->
        {:error, :too_many_redirects}

      [] ->
        {:ok, resp}
    end
  end

  defp handle_response(resp, _uri, _opts, _redirects_left), do: {:ok, resp}

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
    if Enum.all?(ips, &Plausible.IP.Tools.allowed?/1) do
      {:ok, ips}
    else
      {:error, :restricted_address}
    end
  end
end
