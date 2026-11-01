defmodule PlausibleWeb.OAuth.TokenControllerTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.OAuth
  alias Plausible.OAuth.{ProtectedResources, Token}

  setup do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)

    code = "plausible-oauth-ac-test-code"
    verifier = String.duplicate("v", 43)
    resource = ProtectedResources.mcp()

    auth_code =
      insert(:oauth_authorization_code,
        user: user,
        team: team,
        resource: ProtectedResources.get_resource_url(resource),
        scopes: resource.scopes_supported,
        code: code,
        verifier: verifier
      )

    valid_params = %{
      "grant_type" => "authorization_code",
      "client_id" => auth_code.client_id,
      "code" => code,
      "code_verifier" => verifier,
      "redirect_uri" => auth_code.redirect_uri,
      "resource" => auth_code.resource
    }

    {:ok, auth_code: auth_code, resource: resource, valid_params: valid_params}
  end

  test "rejects a request with no grant_type" do
    conn = build_conn() |> post("/login/oauth/token", %{})

    assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                     json_response(conn, 400)
  end

  test "rejects unknown grant_type" do
    conn =
      build_conn()
      |> post("/login/oauth/token", %{"grant_type" => "foo"})

    assert_matches ^strict_map(%{"error" => "unsupported_grant_type"}) =
                     json_response(conn, 400)
  end

  test "requires every parameter of the authorization_code grant", %{
    valid_params: valid_params
  } do
    for param <- Map.keys(valid_params) -- ["grant_type"] do
      conn = build_conn() |> post("/login/oauth/token", Map.delete(valid_params, param))

      assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                       json_response(conn, 400)

      # empty param is the same as missing param
      conn = build_conn() |> post("/login/oauth/token", %{valid_params | param => ""})

      assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                       json_response(conn, 400)
    end
  end

  test "rejects a code redeemed under a different client_id", %{valid_params: valid_params} do
    params = %{valid_params | "client_id" => "https://other.example.com/oauth-metadata"}

    conn = build_conn() |> post("/login/oauth/token", params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)
  end

  test "rejects a mismatched redirect_uri", %{valid_params: valid_params} do
    params = %{valid_params | "redirect_uri" => "https://other.example.com/callback"}

    conn = build_conn() |> post("/login/oauth/token", params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)
  end

  test "rejects a mismatched resource", %{valid_params: valid_params} do
    params = %{valid_params | "resource" => "https://elsewhere.example.com/mcp"}

    conn = build_conn() |> post("/login/oauth/token", params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)
  end

  test "rejects wrong PKCE verifier, grant can't be used even if correct verifier presented after",
       %{valid_params: valid_params} do
    params = %{valid_params | "code_verifier" => "not-the-verifier"}

    conn = build_conn() |> post("/login/oauth/token", params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)

    conn = build_conn() |> post("/login/oauth/token", valid_params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)
  end

  test "exchanges a valid code for a bearer token bound to the code", %{
    valid_params: valid_params,
    auth_code: auth_code,
    resource: resource
  } do
    resp_conn = build_conn() |> post("/login/oauth/token", valid_params)

    resp = json_response(resp_conn, 200)

    assert get_resp_header(resp_conn, "cache-control") == ["no-store"]
    assert get_resp_header(resp_conn, "pragma") == ["no-cache"]

    assert_matches ^strict_map(%{
                     "access_token" =>
                       ^any(
                         :string,
                         &String.starts_with?(&1, Token.plaintext_prefix(:access))
                       ),
                     "refresh_token" =>
                       ^any(
                         :string,
                         &String.starts_with?(&1, Token.plaintext_prefix(:refresh))
                       ),
                     "token_type" => "Bearer",
                     "expires_in" => ^OAuth.access_token_ttl_seconds(),
                     "scope" => "sites:read:*"
                   }) = resp

    refute resp["refresh_token"] == resp["access_token"]

    assert {:ok, grant, _role} = OAuth.find_access_token(resp["access_token"], resource)

    assert_matches %{
                     user: %{id: ^auth_code.user_id},
                     team: %{id: ^auth_code.team_id},
                     resource: ^auth_code.resource,
                     refresh_token_hash: ^Token.hash(resp["refresh_token"]),
                     revoked_at: nil
                   } = grant
  end

  test "code can be exchanged only once", %{valid_params: valid_params} do
    assert build_conn() |> post("/login/oauth/token", valid_params) |> json_response(200)

    conn = build_conn() |> post("/login/oauth/token", valid_params)

    assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                     json_response(conn, 400)
  end

  test "rejects parameters provided in the query string", %{valid_params: valid_params} do
    conn =
      build_conn() |> post("/login/oauth/token?" <> URI.encode_query(valid_params), %{})

    assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                     json_response(conn, 400)

    # passes when same params presented in body
    assert build_conn() |> post("/login/oauth/token", valid_params) |> json_response(200)
  end

  test "refuses requests with Authorization header", %{valid_params: valid_params} do
    for header <- ["", "Basic x", "Bearer x"] do
      resp_conn =
        build_conn()
        |> put_req_header("authorization", header)
        |> post("/login/oauth/token", valid_params)

      assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                       json_response(resp_conn, 400)

      assert get_resp_header(resp_conn, "www-authenticate") == []
    end

    # passes when same params presented without Authorization header
    assert build_conn() |> post("/login/oauth/token", valid_params) |> json_response(200)
  end

  describe "refresh_token grant" do
    setup %{auth_code: auth_code} do
      refresh_token = Token.generate(:refresh).raw

      grant =
        insert(:oauth_grant,
          user_id: auth_code.user_id,
          team_id: auth_code.team_id,
          refresh_token: refresh_token
        )

      valid_refresh_params = %{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token,
        "client_id" => grant.client_id,
        "resource" => grant.resource,
        "scope" => Enum.join(grant.scopes, " ")
      }

      {:ok, grant: grant, valid_refresh_params: valid_refresh_params}
    end

    test "requires refresh_token", %{valid_refresh_params: valid_refresh_params} do
      for params <- [
            Map.delete(valid_refresh_params, "refresh_token"),
            %{valid_refresh_params | "refresh_token" => ""}
          ] do
        conn = build_conn() |> post("/login/oauth/token", params)

        assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                         json_response(conn, 400)
      end
    end

    test "rejects request with optional params when they are malformed", %{
      valid_refresh_params: valid_refresh_params
    } do
      for {param_key, invalid_value} <- [
            {"client_id", ["https://other.example.com/oauth-metadata"]},
            {"client_id", ""},
            {"resource", ["https://other.example.com/mcp"]},
            {"scope", ["admin"]}
          ] do
        conn =
          build_conn()
          |> post("/login/oauth/token", %{valid_refresh_params | param_key => invalid_value})

        assert_matches ^strict_map(%{"error" => "invalid_request"}) =
                         json_response(conn, 400)
      end
    end

    test "issues a new token pair on the same grant", %{
      grant: grant,
      valid_refresh_params: valid_refresh_params,
      resource: resource
    } do
      resp_conn = build_conn() |> post("/login/oauth/token", valid_refresh_params)

      resp = json_response(resp_conn, 200)

      assert get_resp_header(resp_conn, "cache-control") == ["no-store"]
      assert get_resp_header(resp_conn, "pragma") == ["no-cache"]

      assert_matches ^strict_map(%{
                       "access_token" =>
                         ^any(
                           :string,
                           &String.starts_with?(&1, Token.plaintext_prefix(:access))
                         ),
                       "refresh_token" =>
                         ^any(
                           :string,
                           &String.starts_with?(&1, Token.plaintext_prefix(:refresh))
                         ),
                       "token_type" => "Bearer",
                       "expires_in" => ^OAuth.access_token_ttl_seconds(),
                       "scope" => "sites:read:*"
                     }) = resp

      refute resp["refresh_token"] == valid_refresh_params["refresh_token"]

      assert {:ok, %{id: grant_id}, _role} =
               OAuth.find_access_token(resp["access_token"], resource)

      assert grant_id == grant.id
    end

    test "accepts a request carrying only grant_type and refresh_token", %{
      valid_refresh_params: valid_refresh_params
    } do
      params = Map.take(valid_refresh_params, ["grant_type", "refresh_token"])

      assert build_conn() |> post("/login/oauth/token", params) |> json_response(200)
    end

    test "rejects an unknown refresh token", %{valid_refresh_params: valid_refresh_params} do
      params = %{valid_refresh_params | "refresh_token" => Token.generate(:refresh).raw}

      conn = build_conn() |> post("/login/oauth/token", params)

      assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                       json_response(conn, 400)
    end

    test "rejects a mismatched client_id", %{valid_refresh_params: valid_refresh_params} do
      params = %{valid_refresh_params | "client_id" => "https://other.example.com/oauth-metadata"}

      conn = build_conn() |> post("/login/oauth/token", params)

      assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                       json_response(conn, 400)
    end

    test "rejects a scope that was not granted", %{valid_refresh_params: valid_refresh_params} do
      params = %{valid_refresh_params | "scope" => "stats:write:*"}

      conn = build_conn() |> post("/login/oauth/token", params)

      assert_matches ^strict_map(%{"error" => "invalid_scope"}) =
                       json_response(conn, 400)
    end

    test "replay during grace: the previous refresh token is exchanged again", %{
      grant: grant,
      valid_refresh_params: valid_refresh_params,
      resource: resource
    } do
      # client presents the refresh token, it's accepted, but the client loses the response
      %{"access_token" => lost_access_token} =
        build_conn() |> post("/login/oauth/token", valid_refresh_params) |> json_response(200)

      # client presents the same refresh token again, it's accepted
      %{"access_token" => access_token} =
        build_conn() |> post("/login/oauth/token", valid_refresh_params) |> json_response(200)

      grant_id = grant.id
      assert {:error, :invalid_token} = OAuth.find_access_token(lost_access_token, resource)
      assert {:ok, %{id: ^grant_id}, _role} = OAuth.find_access_token(access_token, resource)

      # the original refresh token is not on file any more, so it's refused without revoking the grant
      conn = build_conn() |> post("/login/oauth/token", valid_refresh_params)

      assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                       json_response(conn, 400)

      assert {:ok, _grant, _role} = OAuth.find_access_token(access_token, resource)
    end

    test "replay outside grace: the grant is revoked", %{
      grant: grant,
      valid_refresh_params: valid_refresh_params
    } do
      %{"refresh_token" => rotated} =
        build_conn() |> post("/login/oauth/token", valid_refresh_params) |> json_response(200)

      grant
      |> Plausible.Repo.reload!()
      |> Ecto.Changeset.change(
        rotated_at:
          :second
          |> NaiveDateTime.utc_now()
          |> NaiveDateTime.add(
            -OAuth.refresh_grace_period_seconds(),
            :second
          )
      )
      |> Plausible.Repo.update!()

      conn = build_conn() |> post("/login/oauth/token", valid_refresh_params)

      assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                       json_response(conn, 400)

      conn =
        build_conn()
        |> post("/login/oauth/token", %{valid_refresh_params | "refresh_token" => rotated})

      assert_matches ^strict_map(%{"error" => "invalid_grant"}) =
                       json_response(conn, 400)

      assert %{revoked_at: %NaiveDateTime{}} = Plausible.Repo.reload!(grant)
    end
  end
end
