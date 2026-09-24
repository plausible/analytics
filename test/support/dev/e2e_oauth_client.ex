defmodule PlausibleWeb.E2E.OAuthClient do
  @moduledoc """
  Serves the Client ID Metadata Document `Plausible.OAuth.CIMD` fetches, wired in
  as that fetch's `:plug` - the seam `Req.Test` occupies under `MIX_ENV=test`.
  Values come from `config/.env.e2e_test`, which the Playwright spec reads too.
  """

  @spec client_id() :: String.t()
  def client_id(), do: fetch!("E2E_OAUTH_CLIENT_ID")

  @spec client_name() :: String.t()
  def client_name(), do: fetch!("E2E_OAUTH_CLIENT_NAME")

  @spec redirect_uri() :: String.t()
  def redirect_uri(), do: fetch!("E2E_OAUTH_REDIRECT_URI")

  @doc """
  The hostname the document is served from, or `nil` when no e2e client is
  configured. Consulted on every DNS lookup, so it must not raise.
  """
  @spec host() :: String.t() | nil
  def host() do
    case System.get_env("E2E_OAUTH_CLIENT_ID") do
      nil -> nil
      client_id -> URI.parse(client_id).host
    end
  end

  @spec document() :: map()
  def document() do
    %{
      "client_id" => client_id(),
      "client_name" => client_name(),
      "redirect_uris" => [redirect_uri()]
    }
  end

  defp fetch!(var) do
    System.get_env(var) ||
      raise "#{var} is not set - the e2e OAuth client is defined in config/.env.e2e_test"
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, JSON.encode!(document()))
  end
end

defmodule PlausibleWeb.E2E.DnsLookup do
  @moduledoc """
  Resolves the e2e OAuth client's hostname, so `Plausible.SSRF` - which screens
  the address before any request is made - lets the metadata fetch through.
  Every other name resolves for real.
  """

  @behaviour Plausible.DnsLookupInterface

  # A public address, since the SSRF guard refuses private, loopback and
  # documentation ranges. Nothing connects to it: the fetch is served by a plug.
  @address {93, 184, 216, 34}

  @impl Plausible.DnsLookupInterface
  def lookup(name, class, type, opts, timeout) do
    host = PlausibleWeb.E2E.OAuthClient.host()

    if not is_nil(host) and List.to_string(name) == host do
      case type do
        :a -> [@address]
        :aaaa -> []
      end
    else
      Plausible.DnsLookup.lookup(name, class, type, opts, timeout)
    end
  end
end
