defmodule Plausible.Auth.SSO.Domain.Verification do
  @moduledoc """
  SSO domain ownership verification chain

  1. DNS TXT `{domain}` record lookup.
     Successful expectation contains `plausible-sso-verification={domain-identifier}` record.

  2. HTTP GET lookup at `https://{domain}/plausible-sso-verification`
     Successful expectation contains `{domain-identifier}` in the body.

  3. META tag lookup at `https://{domain}`
     Successful expectation contains:

       ```html
       <meta name="plausible-sso-verification" content="{domain-identifier}">
       ```

     in the body of `text/html` type.
  """

  alias Plausible.Auth.SSO.Domain
  require Domain

  @prefix "plausible-sso-verification"

  @spec run(String.t(), String.t(), Keyword.t()) ::
          {:ok, Domain.verification_method()} | {:error, :unverified}
  def run(sso_domain, domain_identifier, opts \\ []) do
    available_methods = Domain.verification_methods()
    methods = Keyword.get(opts, :methods, available_methods)
    true = Enum.all?(methods, &(&1 in available_methods))

    Enum.reduce_while(methods, {:error, :unverified}, fn method, acc ->
      case apply(__MODULE__, method, [sso_domain, domain_identifier, opts]) do
        true -> {:halt, {:ok, method}}
        false -> {:cont, acc}
      end
    end)
  end

  @spec url(String.t(), String.t(), Keyword.t()) :: boolean()
  def url(sso_domain, domain_identifier, opts \\ []) do
    url_override = Keyword.get(opts, :url_override)

    with :ok <- safe_to_request(sso_domain, url_override),
         %Req.Response{body: body} when is_binary(body) <-
           run_request(url_override || "https://" <> Path.join(sso_domain, @prefix)) do
      String.trim(body) == domain_identifier
    else
      _ ->
        false
    end
  end

  @spec meta_tag(String.t(), String.t(), Keyword.t()) :: boolean()
  def meta_tag(sso_domain, domain_identifier, opts \\ []) do
    url_override = Keyword.get(opts, :url_override)

    with :ok <- safe_to_request(sso_domain, url_override),
         %Req.Response{body: body} = response when is_binary(body) <-
           run_request(url_override || "https://#{sso_domain}"),
         true <- html?(response),
         html <- LazyHTML.from_document(body),
         [_ | _] <-
           LazyHTML.query(html, ~s|meta[name="#{@prefix}"][content="#{domain_identifier}"]|)
           |> Enum.into([]) do
      true
    else
      _ ->
        false
    end
  end

  @spec dns_txt(String.t(), String.t()) :: boolean()
  def dns_txt(sso_domain, domain_identifier, opts \\ []) do
    record_value = to_charlist("#{@prefix}=#{domain_identifier}")

    timeout = Keyword.get(opts, :timeout, 5_000)
    nameservers = Keyword.get(opts, :nameservers)

    lookup_opts =
      case nameservers do
        nil ->
          [timeout: timeout]

        [_ | _] ->
          [timeout: timeout, nameservers: nameservers]
      end

    sso_domain
    |> to_charlist()
    |> :inet_res.lookup(:in, :txt, lookup_opts, timeout)
    |> Enum.find_value(false, fn
      [^record_value] -> true
      _ -> false
    end)
  end

  defp html?(%Req.Response{headers: headers}) do
    headers
    |> Map.get("content-type", "")
    |> List.wrap()
    |> List.first()
    |> String.contains?("text/html")
  end

  @resolve_timeout 1_000

  # When an explicit `url_override` is provided (test seam), the request
  # targets a known local endpoint, so the SSRF guard is skipped. In
  # production the host is always the user-controlled `sso_domain`: resolve it
  # and refuse to issue the request if it points at an internal address. This
  # closes the public-hostname -> private-IP vector that `valid_domain?/1`
  # cannot catch with a purely syntactic check.
  @spec safe_to_request(String.t(), String.t() | nil) :: :ok | :error
  defp safe_to_request(_sso_domain, url_override) when is_binary(url_override), do: :ok

  defp safe_to_request(sso_domain, nil) do
    if host_safe?(sso_domain), do: :ok, else: :error
  end

  # Resolves both A and AAAA records and rejects the host if any resolved
  # address is internal (or if it is a literal internal IP). AAAA is resolved
  # as well as A because the HTTP client will happily connect over IPv6: a host
  # with a public A record but an internal AAAA record would otherwise slip
  # through. An unresolvable host is treated as unsafe.
  defp host_safe?(host) when is_binary(host) and host != "" do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, ip} -> not Plausible.SSRFProtection.internal_ip?(ip)
      {:error, _} -> not Plausible.SSRFProtection.any_internal?(resolve(host))
    end
  end

  defp host_safe?(_), do: false

  defp resolve(host) do
    charlist = to_charlist(host)
    lookup(charlist, :a) ++ lookup(charlist, :aaaa)
  end

  defp lookup(charlist, type) do
    Plausible.DnsLookup.impl().lookup(
      charlist,
      :in,
      type,
      [timeout: @resolve_timeout],
      @resolve_timeout
    )
  end

  defp run_request(base_url) do
    fetch_body_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []

    opts =
      Keyword.merge(
        [
          base_url: base_url,
          max_redirects: 4,
          max_retries: 3,
          retry_log_level: :warning
        ],
        fetch_body_opts
      )

    {_req, resp} =
      opts
      |> Req.new()
      |> Req.Request.prepend_response_steps(plausible_ssrf_guard: &block_internal_redirect/1)
      |> Req.Request.run_request()

    resp
  end

  # Req re-resolves DNS for every redirect hop, so the `safe_to_request/2`
  # preflight only covers the first request. This response step runs before
  # Req's built-in `:redirect` step and refuses to follow a 3xx whose
  # `Location` resolves to an internal address, closing the
  # public-domain -> redirect -> internal-host pivot. Redirects are still
  # followed for legitimate targets (e.g. apex -> www, http -> https), which
  # customers commonly rely on. This does not close DNS rebinding: the actual
  # connection is made by Finch, which re-resolves the host independently.
  defp block_internal_redirect({request, %Req.Response{status: status} = response})
       when status in [301, 302, 303, 307, 308] do
    case Req.Response.get_header(response, "location") do
      [location | _] ->
        target_host =
          request.url
          |> URI.merge(URI.parse(location))
          |> Map.get(:host)

        if host_safe?(target_host) do
          {request, response}
        else
          Req.Request.halt(request, %{response | body: ""})
        end

      [] ->
        {request, response}
    end
  end

  defp block_internal_redirect(request_response), do: request_response

  @after_compile __MODULE__
  def __after_compile__(_env, _bytecode) do
    available_methods = Domain.verification_methods()

    exported_funs =
      :functions
      |> __MODULE__.__info__()
      |> Enum.map(&elem(&1, 0))

    Enum.each(
      available_methods,
      fn method ->
        if method not in exported_funs do
          raise "#{method} must be implemented in #{__MODULE__}"
        end
      end
    )
  end
end
