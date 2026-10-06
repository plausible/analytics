defmodule PlausibleWeb.Plugs.AuthorizeOAuthAPITest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.OAuth
  alias Plausible.OAuth.{Grant, ProtectedResources, Token}
  alias PlausibleWeb.Plugs.AuthorizeOAuthAPI

  doctest PlausibleWeb.Plugs.AuthorizeOAuthAPI, import: true

  setup do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)

    {:ok, conn: plug_conn(), user: user, team: team}
  end

  test "assigns the user, team, role and granted scopes", %{
    conn: conn,
    user: user,
    team: team
  } do
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    conn = authorize(conn, access_token)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.current_team.id == team.id
    assert conn.assigns.current_team_role == :owner
    assert conn.assigns.oauth_scopes == ProtectedResources.mcp().scopes_supported
  end

  test "assigns the role the user currently holds, not the one they had", %{
    conn: conn,
    user: user,
    team: team
  } do
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    Plausible.Repo.get_by!(Plausible.Teams.Membership, user_id: user.id, team_id: team.id)
    |> Ecto.Changeset.change(role: :viewer)
    |> Plausible.Repo.update!()

    assert authorize(conn, access_token).assigns.current_team_role == :viewer
  end

  test "halts once the user is demoted to a role that cannot hold a grant", %{
    conn: conn,
    user: user,
    team: team
  } do
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    Plausible.Repo.get_by!(Plausible.Teams.Membership, user_id: user.id, team_id: team.id)
    |> Ecto.Changeset.change(role: :guest)
    |> Plausible.Repo.update!()

    conn = authorize(conn, access_token)

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
  end

  test "halts once the user is no longer a member of the team, but does not by itself revoke the token",
       %{
         conn: conn,
         user: user,
         team: team
       } do
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    remove_from_team(user, team)

    conn = authorize(conn, access_token)

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)

    assert ["Bearer resource_metadata=" <> _ = challenge] =
             get_resp_header(conn, "www-authenticate")

    assert challenge =~ ~s(error="invalid_token")

    assert %Grant{revoked_at: nil} =
             Plausible.Repo.get_by!(Grant, access_token_hash: Token.hash(access_token))
  end

  test "halts on a missing token", %{conn: conn} do
    conn = conn |> get("/") |> AuthorizeOAuthAPI.call(resource: ProtectedResources.mcp())

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "unauthorized"}) = json_response(conn, 401)
  end

  test "points a caller with no token at the metadata document", %{conn: conn} do
    conn = conn |> get("/") |> AuthorizeOAuthAPI.call(resource: ProtectedResources.mcp())

    assert [challenge] = get_resp_header(conn, "www-authenticate")

    assert challenge ==
             ~s(Bearer resource_metadata="#{PlausibleWeb.Endpoint.url()}/.well-known/oauth-protected-resource/mcp")
  end

  test "halts on an unknown token", %{conn: conn} do
    conn = authorize(conn, "made-up")

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
  end

  test "halts on an expired token", %{conn: conn, user: user, team: team} do
    access_token = Token.generate(:access).raw

    insert(:oauth_grant,
      user: user,
      team: team,
      access_token: access_token,
      access_token_expires_at: NaiveDateTime.utc_now(:second)
    )

    conn = authorize(conn, access_token)

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
  end

  test "halts on a revoked token", %{conn: conn, user: user, team: team} do
    access_token = Token.generate(:access).raw

    :oauth_grant
    |> insert(user: user, team: team, access_token: access_token)
    |> OAuth.revoke_grant()

    conn = authorize(conn, access_token)

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
  end

  test "halts on a token issued for another resource", %{conn: conn, user: user, team: team} do
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> get("/")
      |> AuthorizeOAuthAPI.call(resource: %{resource_path: "/elsewhere", scopes_supported: []})

    assert conn.halted
    assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
  end

  test "halts once the team's hourly request limit is spent, spends the same limit as Stats / Sites API keys",
       %{
         conn: conn,
         user: user,
         team: team
       } do
    team = team |> Ecto.Changeset.change(hourly_api_request_limit: 1) |> Plausible.Repo.update!()

    stats_api_key = insert(:api_key, user: user, team: team, scopes: ["stats:read:*"])
    access_token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: access_token)

    conn_within_limit = authorize(conn, access_token)
    refute conn_within_limit.halted

    conn_oauth_over_limit = authorize(plug_conn(), access_token)

    assert conn_oauth_over_limit.halted

    assert_matches ^strict_map(%{"error" => "too_many_requests"}) =
                     json_response(conn_oauth_over_limit, 429)

    conn_api_over_limit =
      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{stats_api_key.key}")
      |> get("/api/v1/sites")

    assert conn_api_over_limit.halted

    assert_matches ^strict_map(%{
                     "error" =>
                       "Too many API requests. The limit is 1 per hour. Please contact us to request more capacity."
                   }) = json_response(conn_api_over_limit, 429)
  end

  defp plug_conn() do
    build_conn()
    |> put_private(PlausibleWeb.FirstLaunchPlug, :skip)
    |> bypass_through(PlausibleWeb.Router)
  end

  defp authorize(conn, access_token) do
    conn
    |> put_req_header("authorization", "Bearer #{access_token}")
    |> get("/")
    |> AuthorizeOAuthAPI.call(resource: ProtectedResources.mcp())
  end

  defp remove_from_team(user, team) do
    Plausible.Repo.get_by!(Plausible.Teams.Membership, user_id: user.id, team_id: team.id)
    |> Plausible.Repo.delete!()
  end
end
