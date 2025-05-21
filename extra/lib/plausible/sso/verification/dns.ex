defmodule Plausible.SSO.Verification do
  @prefix "plausible-sso-verification"

  def magic_file_found?(sso_domain, domain_identifier) do
    resp = run_request("https://" <> Path.join(sso_domain, @prefix))

    case resp do
      %Req.Response{body: body}
      when is_binary(body) ->
        String.trim(body) == domain_identifier

      _ ->
        false
    end
  end

  def meta_header_found?(sso_domain, domain_identifier) do
    resp = run_request("https://#{sso_domain}")

    case resp do
      %Req.Response{body: body} = response
      when is_binary(body) ->
        with true <- html?(response),
             {:ok, html} <- Floki.parse_document(body),
             [_] <- Floki.find(html, ~s|meta[name="#{@prefix}"][content="#{domain_identifier}"]|) do
          true
        else
          _ ->
            false
        end

      _ ->
        false
    end
  end

  def dns_txt_entry_found?(sso_domain, domain_identifier, opts \\ []) do
    record_value = to_charlist("#{@prefix}=#{domain_identifier}")

    lookup_fn =
      Application.get_env(:plausible, __MODULE__)[:dns_record_lookup_fn] || (&:inet_res.lookup/5)

    true = is_function(lookup_fn, 4)

    {timeout, opts} = Keyword.pop(opts, :timeout, 5_000)

    sso_domain
    |> to_charlist()
    |> lookup_fn.(:in, :txt, opts, timeout)
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
end
