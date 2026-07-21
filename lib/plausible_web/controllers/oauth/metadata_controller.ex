defmodule PlausibleWeb.OAuth.MetadataController do
  @moduledoc """
  Serves the discovery documents required for OAuth 2.1 + MCP:

    * RFC 9728 Protected Resource Metadata (PRM) for the `/mcp` resource.
    * RFC 8414 Authorization Server metadata, advertising CIMD support and
      **no** `registration_endpoint` (client registration is CIMD-only).
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth

  def protected_resource(conn, _params) do
    json(conn, %{
      resource: mcp_url(),
      authorization_servers: [issuer()],
      scopes_supported: OAuth.supported_scopes(),
      bearer_methods_supported: ["header"]
    })
  end

  def authorization_server(conn, _params) do
    issuer = issuer()

    json(conn, %{
      issuer: issuer,
      authorization_endpoint: issuer <> "/oauth/authorize",
      token_endpoint: issuer <> "/oauth/token",
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      scopes_supported: OAuth.supported_scopes(),
      client_id_metadata_document_supported: true
    })
  end

  defp issuer(), do: PlausibleWeb.Endpoint.url()
  defp mcp_url(), do: issuer() <> "/mcp"
end
