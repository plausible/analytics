defmodule PlausibleWeb.OAuth.MetadataController do
  @moduledoc """
  Serves the discovery documents an MCP client walks to learn how to authenticate for `/mcp` endpoint.
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth.ProtectedResources
  alias PlausibleWeb.Endpoint

  @mcp ProtectedResources.mcp()

  @doc """
  Serves the [RFC 9728 Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728.html#name-protected-resource-metadata)
  naming `/mcp` as the resource and pointing at the authorization server that
  protects it.
  """
  def mcp_protected_resource(conn, _params) do
    json(conn, %{
      resource: ProtectedResources.get_resource_url(@mcp),
      authorization_servers: [Endpoint.url()],
      scopes_supported: @mcp.scopes_supported,
      bearer_methods_supported: ["header"]
    })
  end

  @authorization_endpoint "/login/oauth/authorize"
  @token_endpoint "/login/oauth/token"

  @doc """
  Serves the [RFC 8414 Authorization Server Metadata](https://www.rfc-editor.org/rfc/rfc8414.html#section-2)
  advertising the authorize and token endpoints and the grants they accept.
  """
  def authorization_server(conn, _params) do
    json(conn, %{
      issuer: Endpoint.url(),
      authorization_endpoint: Endpoint.url() <> @authorization_endpoint,
      token_endpoint: Endpoint.url() <> @token_endpoint,
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      client_id_metadata_document_supported: true
    })
  end
end
