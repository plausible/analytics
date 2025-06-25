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
    resp = run_request(url_override || "https://" <> Path.join(sso_domain, @prefix))

    case resp do
      %Req.Response{body: body}
      when is_binary(body) ->
        String.trim(body) == domain_identifier

      _ ->
        false
    end
  end

  @spec meta_tag(String.t(), String.t(), Keyword.t()) :: boolean()
  def meta_tag(sso_domain, domain_identifier, opts \\ []) do
    url_override = Keyword.get(opts, :url_override)

    with %Req.Response{body: body} = response when is_binary(body) <-
           run_request(url_override || "https://#{sso_domain}"),
         true <- html?(response),
         {:ok, html} <- Floki.parse_document(body),
         [_ | _] <- Floki.find(html, ~s|meta[name="#{@prefix}"][content="#{domain_identifier}"]|) do
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

    {_req, resp} = opts |> Req.new() |> Req.Request.run_request()
    resp
  end

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
