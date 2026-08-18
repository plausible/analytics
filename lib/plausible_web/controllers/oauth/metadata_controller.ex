defmodule PlausibleWeb.OAuth.MetadataController do
  @moduledoc """
  Serves the discovery documents an MCP client walks to learn how to authenticate for `/mcp` endpoint.
  """

  use PlausibleWeb, :controller

  @doc """
  Serves the [RFC 9728 Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728.html#name-protected-resource-metadata)
  naming `/mcp` as the resource and pointing at the authorization server that
  protects it.
  """
  def protected_resource(conn, _params) do
    not_implemented(conn)
  end

  @doc """
  Serves the [RFC 8414 Authorization Server Metadata](https://www.rfc-editor.org/rfc/rfc8414.html#section-2)
  advertising the authorize and token endpoints and the grants they accept.
  """
  def authorization_server(conn, _params) do
    not_implemented(conn)
  end

  defp not_implemented(conn) do
    conn
    |> put_status(501)
    |> json(%{error: "not_implemented"})
  end
end
