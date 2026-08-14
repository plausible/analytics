defmodule PlausibleWeb.OAuth.MetadataControllerTest do
  use PlausibleWeb.ConnCase, async: false

  describe "with :mcp_server enabled" do
    setup do
      # Enable the global flag via the Ecto store (sandbox-scoped, rolled back at
      # the end of the test). The cache is flushed on exit so the flag reads back
      # as disabled for subsequent tests without a post-sandbox DB write.
      FunWithFlags.enable(:mcp_server)
      on_exit(fn -> FunWithFlags.Store.Cache.flush() end)
      :ok
    end

    test "GET /.well-known/oauth-authorization-server advertises CIMD and no DCR", %{conn: conn} do
      resp = conn |> get("/.well-known/oauth-authorization-server") |> json_response(200)

      assert resp["issuer"] == PlausibleWeb.Endpoint.url()
      assert resp["authorization_endpoint"] =~ "/login/oauth/authorize"
      assert resp["token_endpoint"] =~ "/login/oauth/token"
      assert resp["response_types_supported"] == ["code"]
      assert resp["grant_types_supported"] == ["authorization_code", "refresh_token"]
      assert resp["code_challenge_methods_supported"] == ["S256"]
      assert resp["token_endpoint_auth_methods_supported"] == ["none"]
      assert resp["client_id_metadata_document_supported"] == true
      assert "stats:read:*" in resp["scopes_supported"]
      # CIMD-only: no dynamic client registration endpoint.
      refute Map.has_key?(resp, "registration_endpoint")
    end

    test "well-known AS metadata is also served under the /mcp suffix", %{conn: conn} do
      resp = conn |> get("/.well-known/oauth-authorization-server/mcp") |> json_response(200)
      assert resp["client_id_metadata_document_supported"] == true
    end

    test "GET /.well-known/oauth-protected-resource returns PRM", %{conn: conn} do
      resp = conn |> get("/.well-known/oauth-protected-resource") |> json_response(200)

      assert resp["resource"] == PlausibleWeb.Endpoint.url() <> "/mcp"
      assert resp["authorization_servers"] == [PlausibleWeb.Endpoint.url()]
      assert resp["bearer_methods_supported"] == ["header"]
      assert "stats:read:*" in resp["scopes_supported"]
    end

    test "PRM is also served under the /mcp suffix", %{conn: conn} do
      resp = conn |> get("/.well-known/oauth-protected-resource/mcp") |> json_response(200)
      assert resp["resource"] == PlausibleWeb.Endpoint.url() <> "/mcp"
    end
  end

  describe "with :mcp_server disabled" do
    test "well-known endpoints 404", %{conn: conn} do
      assert conn |> get("/.well-known/oauth-authorization-server") |> json_response(404)
      assert conn |> get("/.well-known/oauth-protected-resource") |> json_response(404)
    end
  end
end
