defmodule PlausibleWeb.MCP.MCPControllerTest do
  use PlausibleWeb.ConnCase, async: false

  alias Plausible.Repo
  alias Plausible.OAuth.{AccessToken, Token}

  @version "2026-07-28"
  @version_key "io.modelcontextprotocol/protocolVersion"
  @caps_key "io.modelcontextprotocol/clientCapabilities"
  @server_info_key "io.modelcontextprotocol/serverInfo"

  setup do
    FunWithFlags.enable(:mcp_server)
    on_exit(fn -> FunWithFlags.Store.Cache.flush() end)

    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, user: user, team: team}
  end

  defp issue_token(user, team, scopes) do
    access = Token.generate(:access)

    Repo.insert!(
      AccessToken.changeset(%{
        access_token_hash: access.hash,
        access_token_prefix: access.prefix,
        client_id: "https://client.example/meta",
        scopes: scopes,
        user_id: user.id,
        team_id: team.id,
        access_token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })
    )

    access.raw
  end

  # Fully-valid per-request `_meta` for the modern protocol.
  defp meta() do
    %{
      @version_key => @version,
      @caps_key => %{},
      "io.modelcontextprotocol/clientInfo" => %{"name" => "test-client", "version" => "1.0"}
    }
  end

  # Sends a well-formed modern request: injects valid `_meta` into `params` and
  # mirrors the required headers (`MCP-Protocol-Version`, `Mcp-Method`, and
  # `Mcp-Name` for `tools/call`) from the body.
  defp rpc(conn, token, message) do
    method = message.method
    params = message |> Map.get(:params, %{}) |> Map.put(:_meta, meta())
    body = Map.put(message, :params, params)

    headers =
      [{"mcp-protocol-version", @version}, {"mcp-method", method}] ++
        name_header(method, params)

    post_rpc(conn, token, body, headers)
  end

  defp name_header("tools/call", params), do: [{"mcp-name", params[:name]}]
  defp name_header(_method, _params), do: []

  # Posts an arbitrary body and header set - used by the validation tests to
  # deliberately omit or corrupt the envelope.
  defp post_rpc(conn, token, body, headers) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> then(fn conn ->
      Enum.reduce(headers, conn, fn {name, value}, conn ->
        put_req_header(conn, name, value)
      end)
    end)
    |> post("/mcp", Jason.encode!(body))
  end

  describe "authentication" do
    test "401 with WWW-Authenticate when no token is provided", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

      assert json_response(conn, 401)
      [header] = get_resp_header(conn, "www-authenticate")
      assert header =~ "Bearer resource_metadata="
      assert header =~ "/.well-known/oauth-protected-resource"
    end

    test "401 invalid_token with a bogus bearer token", %{conn: conn} do
      conn = rpc(conn, "not-a-real-token", %{jsonrpc: "2.0", id: 1, method: "ping"})

      assert json_response(conn, 401)
      [header] = get_resp_header(conn, "www-authenticate")
      assert header =~ ~s(error="invalid_token")
    end

    test "404 when the flag is disabled", %{conn: conn, user: user, team: team} do
      FunWithFlags.disable(:mcp_server)
      token = issue_token(user, team, ["stats:read:*"])
      conn = rpc(conn, token, %{jsonrpc: "2.0", id: 1, method: "ping"})
      assert json_response(conn, 404)
    end
  end

  describe "JSON-RPC methods" do
    setup %{user: user, team: team} do
      {:ok, token: issue_token(user, team, ["stats:read:*", "sites:read:*"])}
    end

    test "server/discover returns versions, capabilities and identity, no session id",
         %{conn: conn, token: token} do
      conn = rpc(conn, token, %{jsonrpc: "2.0", id: 1, method: "server/discover"})

      resp = json_response(conn, 200)
      assert resp["result"]["supportedVersions"] == [@version]
      assert resp["result"]["capabilities"]["tools"] == %{}
      assert resp["result"]["resultType"] == "complete"
      assert resp["result"]["_meta"][@server_info_key]["name"] == "Plausible Analytics"

      # Stateless: the server never mints or echoes a session id.
      assert get_resp_header(conn, "mcp-session-id") == []
    end

    test "ping returns an empty result with envelope metadata", %{conn: conn, token: token} do
      conn = rpc(conn, token, %{jsonrpc: "2.0", id: 2, method: "ping"})
      resp = json_response(conn, 200)
      assert resp["jsonrpc"] == "2.0"
      assert resp["id"] == 2
      assert resp["result"]["resultType"] == "complete"
      assert resp["result"]["_meta"][@server_info_key]["name"] == "Plausible Analytics"
    end

    test "notifications are acknowledged with 202 and no body", %{conn: conn, token: token} do
      conn = rpc(conn, token, %{jsonrpc: "2.0", method: "notifications/initialized"})
      assert response(conn, 202) == ""
    end

    test "tools/list returns list_sites and query_stats", %{conn: conn, token: token} do
      conn = rpc(conn, token, %{jsonrpc: "2.0", id: 3, method: "tools/list"})
      resp = json_response(conn, 200)
      names = Enum.map(resp["result"]["tools"], & &1["name"])
      assert "list_sites" in names
      assert "query_stats" in names
      assert resp["result"]["resultType"] == "complete"
    end

    test "unknown method returns 404 with a JSON-RPC error", %{conn: conn, token: token} do
      conn = rpc(conn, token, %{jsonrpc: "2.0", id: 4, method: "does/not/exist"})
      resp = json_response(conn, 404)
      assert resp["error"]["code"] == -32_601
    end
  end

  describe "protocol validation" do
    setup %{user: user, team: team} do
      {:ok, token: issue_token(user, team, ["stats:read:*", "sites:read:*"])}
    end

    test "missing MCP-Protocol-Version header -> 400 HeaderMismatch",
         %{conn: conn, token: token} do
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta()}}
      conn = post_rpc(conn, token, body, [{"mcp-method", "ping"}])
      assert json_response(conn, 400)["error"]["code"] == -32_020
    end

    test "header/body protocolVersion mismatch -> 400 HeaderMismatch",
         %{conn: conn, token: token} do
      meta = Map.put(meta(), @version_key, "1900-01-01")
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta}}
      headers = [{"mcp-protocol-version", @version}, {"mcp-method", "ping"}]
      conn = post_rpc(conn, token, body, headers)
      assert json_response(conn, 400)["error"]["code"] == -32_020
    end

    test "tools/call without Mcp-Name -> 400 HeaderMismatch", %{conn: conn, token: token} do
      body = %{
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: %{name: "list_sites", arguments: %{}, _meta: meta()}
      }

      headers = [{"mcp-protocol-version", @version}, {"mcp-method", "tools/call"}]
      conn = post_rpc(conn, token, body, headers)
      assert json_response(conn, 400)["error"]["code"] == -32_020
    end

    test "missing _meta protocolVersion -> 400 Invalid params", %{conn: conn, token: token} do
      meta = Map.delete(meta(), @version_key)
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta}}
      headers = [{"mcp-protocol-version", @version}, {"mcp-method", "ping"}]
      conn = post_rpc(conn, token, body, headers)
      assert json_response(conn, 400)["error"]["code"] == -32_602
    end

    test "missing _meta clientCapabilities -> 400 Invalid params", %{conn: conn, token: token} do
      meta = Map.delete(meta(), @caps_key)
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta}}
      headers = [{"mcp-protocol-version", @version}, {"mcp-method", "ping"}]
      conn = post_rpc(conn, token, body, headers)
      assert json_response(conn, 400)["error"]["code"] == -32_602
    end

    test "unsupported protocol version -> 400 with supported list", %{conn: conn, token: token} do
      old = "2025-06-18"
      meta = Map.put(meta(), @version_key, old)
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta}}
      headers = [{"mcp-protocol-version", old}, {"mcp-method", "ping"}]
      conn = post_rpc(conn, token, body, headers)

      resp = json_response(conn, 400)
      assert resp["error"]["code"] == -32_022
      assert resp["error"]["data"]["supported"] == [@version]
      assert resp["error"]["data"]["requested"] == old
    end

    test "a client-sent Mcp-Session-Id is ignored and never echoed",
         %{conn: conn, token: token} do
      body = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{_meta: meta()}}

      headers = [
        {"mcp-protocol-version", @version},
        {"mcp-method", "ping"},
        {"mcp-session-id", "client-supplied"}
      ]

      conn = post_rpc(conn, token, body, headers)
      assert json_response(conn, 200)
      assert get_resp_header(conn, "mcp-session-id") == []
    end

    test "a JSON-RPC batch (array body) is rejected -> 400 Invalid Request",
         %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!([%{jsonrpc: "2.0", id: 1, method: "ping"}]))

      assert json_response(conn, 400)["error"]["code"] == -32_600
    end

    test "GET /mcp -> 405", %{conn: conn, token: token} do
      conn = conn |> put_req_header("authorization", "Bearer #{token}") |> get("/mcp")
      assert json_response(conn, 405)
    end

    test "DELETE /mcp -> 405", %{conn: conn, token: token} do
      conn = conn |> put_req_header("authorization", "Bearer #{token}") |> delete("/mcp")
      assert json_response(conn, 405)
    end
  end

  describe "tools/call list_sites" do
    test "returns the team's sites", %{conn: conn, user: user, team: team} do
      site = new_site(owner: user)
      token = issue_token(user, team, ["sites:read:*"])

      conn =
        rpc(conn, token, %{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{name: "list_sites", arguments: %{}}
        })

      resp = json_response(conn, 200)
      refute resp["result"]["isError"]
      [%{"type" => "text", "text" => text}] = resp["result"]["content"]
      payload = Jason.decode!(text)
      domains = Enum.map(payload["sites"], & &1["domain"])
      assert site.domain in domains
    end

    test "is denied without the sites:read scope", %{conn: conn, user: user, team: team} do
      token = issue_token(user, team, ["stats:read:*"])

      conn =
        rpc(conn, token, %{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{name: "list_sites", arguments: %{}}
        })

      resp = json_response(conn, 200)
      assert resp["result"]["isError"]
      [%{"text" => text}] = resp["result"]["content"]
      assert text =~ "sites:read:*"
    end
  end

  describe "tools/call query_stats" do
    test "wraps the Stats API query", %{conn: conn, user: user, team: team} do
      subscribe_to_business_plan(team)
      site = new_site(owner: user)
      token = issue_token(user, team, ["stats:read:*"])

      conn =
        rpc(conn, token, %{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{
            name: "query_stats",
            arguments: %{
              site_id: site.domain,
              metrics: ["visitors"],
              date_range: "all"
            }
          }
        })

      resp = json_response(conn, 200)
      refute resp["result"]["isError"]
      [%{"text" => text}] = resp["result"]["content"]
      payload = Jason.decode!(text)
      assert Map.has_key?(payload, "results")
    end

    test "returns an error for a site the token cannot access", %{
      conn: conn,
      user: user,
      team: team
    } do
      other_site = new_site()
      token = issue_token(user, team, ["stats:read:*"])

      conn =
        rpc(conn, token, %{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{
            name: "query_stats",
            arguments: %{site_id: other_site.domain, metrics: ["visitors"], date_range: "all"}
          }
        })

      resp = json_response(conn, 200)
      assert resp["result"]["isError"]
    end

    test "a role downgrade keeps the grant but reduces access via live checks", %{conn: conn} do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      site = new_site(owner: owner)
      member = add_member(team, role: :editor)
      token = issue_token(member, team, ["stats:read:*", "sites:read:*"])

      list_sites = fn ->
        rpc(conn, token, %{
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: %{name: "list_sites", arguments: %{}}
        })
        |> json_response(200)
      end

      # Baseline: as an editor, the member sees the team's site.
      [%{"text" => text}] = list_sites.()["result"]["content"]
      assert site.domain in Enum.map(Jason.decode!(text)["sites"], & &1["domain"])

      # Downgrade the member to a guest (a permission change, not a deletion).
      {:ok, membership} = Plausible.Teams.Memberships.get_team_membership(team, member.id)

      membership
      |> Ecto.Changeset.change(role: :guest)
      |> Repo.update!()

      # The grant is NOT revoked - downgrade isn't a membership deletion...
      assert [_] = Plausible.OAuth.list_grants(member)

      ping = rpc(conn, token, %{jsonrpc: "2.0", id: 9, method: "ping"}) |> json_response(200)
      assert ping["id"] == 9
      assert ping["result"]["resultType"] == "complete"

      # ...but the live per-request check now excludes guests, so no team sites
      # are visible.
      assert Jason.decode!(hd(list_sites.()["result"]["content"])["text"])["sites"] == []
    end
  end
end
