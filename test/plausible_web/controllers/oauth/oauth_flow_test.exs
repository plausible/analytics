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

  describe "GET /oauth/authorize" do
    test "renders the consent screen with client and scope info", %{conn: conn} do
      {_verifier, challenge} = pkce()
      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      html = html_response(conn, 200)
      assert html =~ "Authorize access"
      assert html =~ "Test Client"
      assert html =~ "Stats API"
    end

    test "404s when the :mcp_server flag is disabled", %{conn: conn} do
      FunWithFlags.disable(:mcp_server)
      {_verifier, challenge} = pkce()
      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))
      assert conn.status == 404
    end

    test "redirects to login when unauthenticated" do
      {_verifier, challenge} = pkce()

      conn =
        build_conn()
        |> get("/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      assert redirected_to(conn) =~ "/login"
    end

    test "renders an error page for an invalid client_id", %{conn: conn} do
      put_fetcher(fn _url -> {:error, :boom} end)
      {_verifier, challenge} = pkce()

      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))
      assert html_response(conn, 400) =~ "Authorization error"
    end

    test "redirects back with error for unsupported response_type", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"response_type" => "token"})

      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(params))
      query = code_from_redirect(conn)
      assert query["error"] == "unsupported_response_type"
      assert query["state"] == "xyz-state"
    end

    test "redirects back with invalid_request when code_challenge missing", %{conn: conn} do
      params = authorize_params("", %{"code_challenge" => ""})
      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(params))
      assert code_from_redirect(conn)["error"] == "invalid_request"
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
      conn = get(conn, "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge)))

      assert html_response(conn, 400) =~ "belong to a team"
    end

    test "POST approve is refused and issues no code", %{conn: conn} do
      {_verifier, challenge} = pkce()

      conn =
        post(conn, "/oauth/authorize", authorize_params(challenge, %{"action" => "approve"}))

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
          "/oauth/authorize",
          authorize_params(challenge, %{"action" => "approve"})
        )

      query = code_from_redirect(conn)
      assert query["state"] == "xyz-state"
      code = query["code"]
      assert is_binary(code)

      # Exchange the code
      resp =
        token_conn()
        |> post("/oauth/token", %{
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

      # The access token authenticates against /mcp
      mcp =
        build_conn()
        |> put_req_header("authorization", "Bearer #{resp["access_token"]}")
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

      assert json_response(mcp, 200)["result"] == %{}

      # Refresh rotates the tokens
      refreshed =
        token_conn()
        |> post("/oauth/token", %{
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
        post(conn, "/oauth/authorize", authorize_params(challenge, %{"action" => "approve"}))

      code = code_from_redirect(conn)["code"]

      exchange = fn ->
        token_conn()
        |> post("/oauth/token", %{
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
        post(conn, "/oauth/authorize", authorize_params(challenge, %{"action" => "deny"}))

      assert code_from_redirect(conn)["error"] == "access_denied"
    end
  end

  describe "POST /oauth/token errors" do
    test "invalid code returns invalid_grant" do
      resp =
        token_conn()
        |> post("/oauth/token", %{
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
        |> post("/oauth/token", %{"grant_type" => "client_credentials"})
        |> json_response(400)

      assert resp["error"] == "unsupported_grant_type"
    end

    test "missing grant_type" do
      resp =
        token_conn()
        |> post("/oauth/token", %{})
        |> json_response(400)

      assert resp["error"] == "invalid_request"
    end
  end
end
