defmodule PlausibleWeb.Plugs.AuthorizeOAuthAPITest do
  use PlausibleWeb.ConnCase, async: false

  alias PlausibleWeb.Plugs.AuthorizeOAuthAPI
  alias Plausible.OAuth
  alias Plausible.OAuth.{AccessToken, Token}
  alias Plausible.Repo

  @redirect_uri "https://client.example/callback"
  @client_id "https://client.example/oauth-metadata"
  @resource "https://plausible.example/mcp"

  setup %{conn: conn} do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, conn: prepare_conn_for_auth(conn), user: user, team: team}
  end

  test "halts 401 with a discovery WWW-Authenticate header when no token is provided", %{
    conn: conn
  } do
    conn = conn |> get("/") |> AuthorizeOAuthAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] == "unauthorized"

    [header] = get_resp_header(conn, "www-authenticate")
    assert header =~ "Bearer resource_metadata="
    assert header =~ "/.well-known/oauth-protected-resource"
    refute header =~ "error="
  end

  test "halts 401 invalid_token for a bogus bearer token", %{conn: conn} do
    conn = call_with_token(conn, "not-a-real-token")

    assert conn.halted
    assert json_response(conn, 401)["error"] == "invalid_token"

    [header] = get_resp_header(conn, "www-authenticate")
    assert header =~ ~s(error="invalid_token")
  end

  test "halts 401 invalid_token for an expired token", %{conn: conn, user: user, team: team} do
    raw = insert_expired_token(user, team, ["stats:read:*"])
    conn = call_with_token(conn, raw)

    assert conn.halted
    assert json_response(conn, 401)["error"] == "invalid_token"
  end

  test "passes and assigns the identity + granted scopes for a valid token", %{
    conn: conn,
    user: user,
    team: team
  } do
    %{access_token: raw} = issue_tokens(user, team, ["stats:read:*", "sites:read:*"])
    conn = call_with_token(conn, raw)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.current_team.id == team.id
    assert conn.assigns.oauth_scopes == ["stats:read:*", "sites:read:*"]
  end

  test "stamps last_used_at on the token when it authenticates", %{
    conn: conn,
    user: user,
    team: team
  } do
    %{access_token: raw} = issue_tokens(user, team, ["stats:read:*"])

    refute call_with_token(conn, raw).halted

    assert {:ok, token} = OAuth.find_access_token(raw)
    assert token.last_used_at
  end

  test "halts 429 when over the burst request limit", %{conn: _conn} do
    patch_env(Plausible.Auth.ApiKey, burst_request_limit: 3, burst_period_seconds: 60)

    user = new_user(team: [hourly_api_request_limit: 1_000])
    team = team_of(user)
    %{access_token: raw} = issue_tokens(user, team, ["stats:read:*"])

    limit = Plausible.Auth.ApiKey.burst_request_limit()

    # A fixed-window limiter lets up to `2 * limit` through near a boundary, so
    # only the `2 * limit + 1`th request is guaranteed to be throttled.
    conns = for _ <- 1..(2 * limit + 1), do: call_with_token(get_fresh_conn(), raw)

    assert throttled = Enum.find(conns, & &1.halted)
    assert json_response(throttled, 429)["error"] == "too_many_requests"
  end

  defp prepare_conn_for_auth(conn) do
    conn
    |> put_private(PlausibleWeb.FirstLaunchPlug, :skip)
    |> bypass_through(PlausibleWeb.Router)
  end

  defp get_fresh_conn(), do: build_conn() |> prepare_conn_for_auth()

  defp call_with_token(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> get("/")
    |> AuthorizeOAuthAPI.call(nil)
  end

  defp issue_tokens(user, team, scopes) do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    attrs = %{
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      code_challenge: challenge,
      code_challenge_method: "S256",
      scopes: scopes,
      resource: @resource
    }

    {:ok, raw} = OAuth.create_authorization_code(user, team, attrs)
    {:ok, code} = OAuth.consume_authorization_code(raw, verifier, @redirect_uri, @resource)
    {:ok, tokens} = OAuth.issue_tokens(code)
    tokens
  end

  defp insert_expired_token(user, team, scopes) do
    access = Token.generate(:access)

    Repo.insert!(
      AccessToken.changeset(%{
        access_token_hash: access.hash,
        access_token_prefix: access.prefix,
        client_id: @client_id,
        scopes: scopes,
        user_id: user.id,
        team_id: team.id,
        access_token_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })
    )

    access.raw
  end
end
