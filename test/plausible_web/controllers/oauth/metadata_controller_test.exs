defmodule PlausibleWeb.OAuth.MetadataControllerTest do
  use PlausibleWeb.ConnCase, async: true

  describe "GET /.well-known/oauth-authorization-server" do
    test "advertises the endpoints, grants and CIMD support", %{conn: conn} do
      issuer = PlausibleWeb.Endpoint.url()

      resp = conn |> get("/.well-known/oauth-authorization-server") |> json_response(200)

      assert_matches ^strict_map(%{
                       "issuer" => ^issuer,
                       "authorization_endpoint" => ^(issuer <> "/login/oauth/authorize"),
                       "token_endpoint" => ^(issuer <> "/login/oauth/token"),
                       "response_types_supported" => ["code"],
                       "grant_types_supported" => ["authorization_code"],
                       "code_challenge_methods_supported" => ["S256"],
                       "token_endpoint_auth_methods_supported" => ["none"],
                       "scopes_supported" => ["sites:read:*"],
                       "client_id_metadata_document_supported" => true
                     }) = resp
    end
  end

  describe "GET /.well-known/oauth-protected-resource/mcp" do
    test "names /mcp as the resource and points at the authorization server", %{conn: conn} do
      issuer = PlausibleWeb.Endpoint.url()

      resp = conn |> get("/.well-known/oauth-protected-resource/mcp") |> json_response(200)

      assert_matches ^strict_map(%{
                       "resource" => ^(issuer <> "/mcp"),
                       "authorization_servers" => [^issuer],
                       "bearer_methods_supported" => ["header"],
                       "scopes_supported" => ["sites:read:*"]
                     }) = resp
    end
  end
end
