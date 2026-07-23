defmodule PlausibleWeb.OAuth.FlowTest do
  use PlausibleWeb.ConnCase, async: false

  @redirect_uri "https://client.example/callback"
  @client_id "https://client.example/oauth-metadata"
  @resource "https://plausible.example/mcp"

  setup %{conn: conn} do
    FunWithFlags.enable(:mcp_server)
    on_exit(fn -> FunWithFlags.Store.Cache.flush() end)

    put_fetcher(fn url ->
      {:ok,
       Jason.encode!(%{
         "client_id" => url,
         "redirect_uris" => [@redirect_uri],
         "client_name" => "Test Client"
       })}
    end)

    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, conn: conn} = log_in(%{user: user, conn: conn})

    {:ok, conn: conn, user: user, team: team}
  end

  defp put_fetcher(fun) do
    Application.put_env(:plausible, Plausible.OAuth, client_metadata_fetcher: fun)
    on_exit(fn -> Application.delete_env(:plausible, Plausible.OAuth) end)
  end

  defp pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp authorize_params(challenge, overrides \\ %{}) do
    Map.merge(
      %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "response_type" => "code",
        "code_challenge" => challenge,
        "code_challenge_method" => "S256",
        "scope" => "stats:read:* sites:read:*",
        "state" => "xyz-state",
        "resource" => @resource
      },
      overrides
    )
  end

  defp token_conn do
    build_conn() |> put_req_header("accept", "application/json")
  end

  defp code_from_redirect(conn) do
    location = redirected_to(conn, 302)
    assert String.starts_with?(location, @redirect_uri)
    %URI{query: query} = URI.parse(location)
    URI.decode_query(query)
  end

  # Models a client following an absolute URL it read out of a discovery
  # document: for an in-process request we only need the path, which is exactly
  # the coupling a real client has — it uses whatever the server advertises.
  defp path_of(url), do: URI.parse(url).path

  # RFC 8414 §3: the authorization server metadata URL is the well-known segment
  # inserted between the issuer's host and path. Our issuer is path-less, so it
  # lands at the origin root.
  defp as_metadata_url(issuer) do
    uri = URI.parse(issuer)

    %{uri | path: "/.well-known/oauth-authorization-server" <> (uri.path || "")}
    |> URI.to_string()
  end

  describe "GET /login/oauth/authorize" do
    test "renders the consent screen with client and scope info", %{conn: conn} do
      {_verifier, challenge} = pkce()
      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      html = html_response(conn, 200)
      assert html =~ "Authorize access"
      assert html =~ "Test Client"
      assert html =~ "Stats API"
    end

    test "404s when the :mcp_server flag is disabled", %{conn: conn} do
      FunWithFlags.disable(:mcp_server)
      {_verifier, challenge} = pkce()
      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))
      assert conn.status == 404
    end

    test "redirects to login when unauthenticated" do
      {_verifier, challenge} = pkce()

      conn =
        build_conn()
        |> get("/login/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      assert redirected_to(conn) =~ "/login"
    end

    test "renders an error page for an invalid client_id", %{conn: conn} do
      put_fetcher(fn _url -> {:error, :boom} end)
      {_verifier, challenge} = pkce()

      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))
      assert html_response(conn, 400) =~ "Authorization error"
    end

    test "redirects back with error for unsupported response_type", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"response_type" => "token"})

      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))
      query = code_from_redirect(conn)
      assert query["error"] == "unsupported_response_type"
      assert query["state"] == "xyz-state"
    end

    test "redirects back with invalid_request when code_challenge missing", %{conn: conn} do
      params = authorize_params("", %{"code_challenge" => ""})
      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))
      assert code_from_redirect(conn)["error"] == "invalid_request"
    end

    test "redirects back with invalid_scope when no supported scope requested", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"scope" => "stats:write:*"})

      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))
      query = code_from_redirect(conn)
      assert query["error"] == "invalid_scope"
      assert query["state"] == "xyz-state"
    end

    test "defaults to all supported scopes when scope is absent", %{conn: conn} do
      {_verifier, challenge} = pkce()

      params =
        challenge
        |> authorize_params()
        |> Map.delete("scope")

      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))
      assert html_response(conn, 200) =~ "Authorize access"
    end
  end

  describe "when the user has no team" do
    setup %{conn: conn} do
      # Re-log-in as a freshly-created user with no team memberships at all.
      {:ok, conn: conn} = log_in(%{user: new_user(), conn: conn})
      {:ok, conn: conn}
    end

    test "GET consent shows an error instead of the form", %{conn: conn} do
      {_verifier, challenge} = pkce()
      conn = get(conn, "/login/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      assert html_response(conn, 400) =~ "belong to a team"
    end

    test "POST approve is refused and issues no code", %{conn: conn} do
      {_verifier, challenge} = pkce()

      conn =
        post(
          conn,
          "/login/oauth/authorize",
          authorize_params(challenge, %{"action" => "approve"})
        )

      assert html_response(conn, 400) =~ "belong to a team"
      assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
    end
  end

  describe "full authorization_code + refresh flow" do
    test "approve -> code -> token -> refresh", %{conn: conn, user: user} do
      {verifier, challenge} = pkce()

      # Approve consent
      conn =
        post(
          conn,
          "/login/oauth/authorize",
          authorize_params(challenge, %{"action" => "approve"})
        )

      query = code_from_redirect(conn)
      assert query["state"] == "xyz-state"
      code = query["code"]
      assert is_binary(code)

      # Exchange the code
      resp =
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri,
          "resource" => @resource
        })
        |> json_response(200)

      assert resp["token_type"] == "Bearer"
      assert is_binary(resp["access_token"])
      assert is_binary(resp["refresh_token"])
      assert resp["expires_in"] == Plausible.OAuth.access_token_ttl()

      # The client name from the CIMD document is captured on the grant.
      assert [grant] = Plausible.OAuth.list_grants(user)
      assert grant.client_name == "Test Client"

      # Refresh rotates the tokens
      refreshed =
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => resp["refresh_token"]
        })
        |> json_response(200)

      assert is_binary(refreshed["access_token"])
      refute refreshed["access_token"] == resp["access_token"]
    end

    test "the code is single-use", %{conn: conn} do
      {verifier, challenge} = pkce()

      conn =
        post(
          conn,
          "/login/oauth/authorize",
          authorize_params(challenge, %{"action" => "approve"})
        )

      code = code_from_redirect(conn)["code"]

      exchange = fn ->
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri,
          "resource" => @resource
        })
      end

      assert exchange.() |> json_response(200)
      assert exchange.() |> json_response(400) |> Map.get("error") == "invalid_grant"
    end

    test "deny redirects with access_denied", %{conn: conn} do
      {_verifier, challenge} = pkce()

      conn =
        post(conn, "/login/oauth/authorize", authorize_params(challenge, %{"action" => "deny"}))

      assert code_from_redirect(conn)["error"] == "access_denied"
    end
  end

  describe "discovery-driven flow (client follows advertised metadata)" do
    # This test hardcodes NO OAuth endpoint path. Every path it hits is read out
    # of the discovery documents at request time: PRM -> authorization server
    # metadata -> {authorization,token}_endpoint. Rename the routes (and the
    # metadata that advertises them) and this test follows along automatically —
    # which is the point: those endpoint locations are discovered, not fixed by
    # the protocol. Contrast the well-known paths, which are fixed by RFC 8414 /
    # RFC 9728 and therefore *are* spelled out literally here.
    test "approve -> code -> token -> refresh through discovered endpoints", %{
      conn: conn,
      user: user
    } do
      # 1. Protected Resource Metadata names the authorization server(s) and the
      #    resource. A client discovers this unauthenticated.
      prm =
        build_conn()
        |> get("/.well-known/oauth-protected-resource")
        |> json_response(200)

      assert [as_issuer] = prm["authorization_servers"]
      resource = prm["resource"]

      # 2. Fetch the authorization server metadata from the discovered issuer and
      #    read the endpoints it advertises.
      as_meta =
        build_conn()
        |> get(path_of(as_metadata_url(as_issuer)))
        |> json_response(200)

      authorize_path = path_of(as_meta["authorization_endpoint"])
      token_path = path_of(as_meta["token_endpoint"])

      # These came from metadata, not from a literal in this test.
      assert String.starts_with?(authorize_path, "/")
      assert String.starts_with?(token_path, "/")

      # 3. Drive the whole grant through the discovered paths and resource only.
      {verifier, challenge} = pkce()

      approve_params =
        challenge
        |> authorize_params(%{"action" => "approve"})
        |> Map.put("resource", resource)

      code =
        conn
        |> post(authorize_path, approve_params)
        |> code_from_redirect()
        |> Map.get("code")

      assert is_binary(code)

      resp =
        token_conn()
        |> post(token_path, %{
          "grant_type" => "authorization_code",
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri,
          "resource" => resource
        })
        |> json_response(200)

      assert resp["token_type"] == "Bearer"
      assert is_binary(resp["access_token"])
      assert is_binary(resp["refresh_token"])
      assert [grant] = Plausible.OAuth.list_grants(user)
      assert grant.client_name == "Test Client"

      # The discovered token endpoint serves refresh too.
      refreshed =
        token_conn()
        |> post(token_path, %{
          "grant_type" => "refresh_token",
          "refresh_token" => resp["refresh_token"]
        })
        |> json_response(200)

      assert is_binary(refreshed["access_token"])
      refute refreshed["access_token"] == resp["access_token"]
    end
  end

  describe "POST /login/oauth/token errors" do
    test "invalid code returns invalid_grant" do
      resp =
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => "nope",
          "code_verifier" => "v",
          "redirect_uri" => @redirect_uri
        })
        |> json_response(400)

      assert resp["error"] == "invalid_grant"
    end

    test "unsupported grant_type" do
      resp =
        token_conn()
        |> post("/login/oauth/token", %{"grant_type" => "client_credentials"})
        |> json_response(400)

      assert resp["error"] == "unsupported_grant_type"
    end

    test "missing grant_type" do
      resp =
        token_conn()
        |> post("/login/oauth/token", %{})
        |> json_response(400)

      assert resp["error"] == "invalid_request"
    end
  end
end
