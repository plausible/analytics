defmodule PlausibleWeb.MCP.MCPControllerTest do
  # Not `async: true`: the end-to-end flow stubs the CIMD fetch and its DNS lookup.
  use PlausibleWeb.ConnCase
  use Plausible.Test.Support.DNS

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth
  alias Plausible.OAuth.{ProtectedResources, Token}

  @version "2026-07-28"

  setup [:create_user, :create_team]

  describe "end to end flow" do
    setup [:create_site, :log_in]

    test "app can be authorized, the acquired token works for listing sites, stops working when revoked",
         %{
           conn: conn,
           user: user,
           site: site
         } do
      client_id = "https://client.example.com/oauth-metadata"
      redirect_uri = "https://client.example.com/callback"

      FunWithFlags.enable(:mcp, for_actor: user)

      stub_dns()

      Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
        Plug.Conn.send_resp(
          conn,
          200,
          Jason.encode!(%{
            "client_id" => client_id,
            "redirect_uris" => [redirect_uri],
            "client_name" => "Test Client"
          })
        )
      end)

      verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
      resource = ProtectedResources.get_resource_url(ProtectedResources.mcp())

      html =
        conn
        |> get(
          "/login/oauth/authorize?" <>
            URI.encode_query(%{
              "client_id" => client_id,
              "redirect_uri" => redirect_uri,
              "response_type" => "code",
              "code_challenge" => challenge,
              "code_challenge_method" => "S256",
              "scope" => "sites:read:*",
              "resource" => resource
            })
        )
        |> html_response(200)

      redirect =
        conn
        |> post("/login/oauth/authorize", %{
          "signed_request" => text_of_attr(html, "input[name=signed_request]", "value"),
          "team" => text_of_attr(html, "input[name=team]", "value"),
          "action" => "approve"
        })
        |> redirected_to(302)

      assert [base, query] = String.split(redirect, "?")
      assert base == redirect_uri

      params = URI.decode_query(query)
      code = params["code"]

      %{"access_token" => access_token, "token_type" => "Bearer"} =
        build_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => redirect_uri,
          "resource" => resource
        })
        |> json_response(200)

      resp = build_conn() |> call_tool(access_token, "list_sites") |> json_response(200)

      assert resp["result"]["isError"] == false
      assert %{"sites" => [returned]} = tool_payload(resp)
      assert returned["domain"] == site.domain

      {:ok, grant, _role} = OAuth.find_access_token(access_token, ProtectedResources.mcp())
      OAuth.revoke_grant(grant)

      assert_matches ^strict_map(%{"error" => "invalid_token"}) =
                       build_conn()
                       |> call_tool(access_token, "list_sites")
                       |> json_response(401)
    end
  end

  describe "authentication" do
    test "401s without a token, pointing at metadata that actually resolves", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", body("tools/list", []))

      assert_matches ^strict_map(%{"error" => "unauthorized"}) = json_response(conn, 401)

      assert [challenge] = get_resp_header(conn, "www-authenticate")
      assert [_, metadata_url] = Regex.run(~r/resource_metadata="([^"]+)"/, challenge)

      assert_matches ^strict_map(%{
                       "resource" =>
                         ^ProtectedResources.get_resource_url(ProtectedResources.mcp()),
                       "authorization_servers" => [^PlausibleWeb.Endpoint.url()],
                       "scopes_supported" => ^ProtectedResources.mcp().scopes_supported,
                       "bearer_methods_supported" => ["header"]
                     }) = build_conn() |> get(URI.parse(metadata_url).path) |> json_response(200)
    end

    # A client picks a protocol version before it holds a token, and a bare 401
    # tells it nothing about which versions the server speaks.
    test "server/discover is answerable without a token", %{conn: conn} do
      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "resultType" => "complete",
                           "_meta" => ^any(:map),
                           "supportedVersions" => ^[@version],
                           "capabilities" => ^strict_map(%{"tools" => ^strict_map(%{})}),
                           "instructions" => ^any(:string),
                           "ttlMs" => ^any(:pos_integer),
                           "cacheScope" => "public"
                         })
                     }) =
                       conn
                       |> put_req_header("mcp-protocol-version", @version)
                       |> put_req_header("mcp-method", "server/discover")
                       |> post("/mcp", body("server/discover", []))
                       |> json_response(200)
    end

    test "every other method still requires a token", %{conn: conn} do
      for method <- ~w(tools/list tools/call) do
        resp_conn =
          conn
          |> recycle()
          |> put_req_header("mcp-protocol-version", @version)
          |> put_req_header("mcp-method", method)
          |> put_req_header("mcp-name", "list_sites")
          |> post("/mcp", body(method, params: %{"name" => "list_sites", "arguments" => %{}}))

        assert_matches ^strict_map(%{"error" => "unauthorized"}) =
                         json_response(resp_conn, 401)
      end
    end

    test "401s an unknown token", %{conn: conn} do
      assert_matches ^strict_map(%{"error" => "invalid_token"}) =
                       conn |> mcp_post("not-a-token", "tools/list") |> json_response(401)
    end

    # A token that is ours, unexpired and unrevoked must still be refused if it
    # was issued for a different resource. This is what pins the controller to
    # `ProtectedResources.mcp()`.
    test "401s a token issued for another resource", %{conn: conn, user: user, team: team} do
      token = Token.generate(:access).raw

      insert(:oauth_grant,
        user: user,
        team: team,
        access_token: token,
        resource: "https://elsewhere.example/mcp"
      )

      assert_matches ^strict_map(%{"error" => "invalid_token"}) =
                       conn |> mcp_post(token, "tools/list") |> json_response(401)
    end

    test "a malformed request on a method needing no token is 400, not a crash" do
      conn =
        build_conn()
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "server/discover")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "server/discover",
          "params" => "not-an-object"
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" => ^strict_map(%{"code" => -32_602, "message" => ^any(:string)})
                     }) = json_response(conn, 400)
    end

    # These only ever answer 405, so they stay unauthenticated - a 401 would hide
    # the signal an older client uses to detect the protocol revision.
    test "GET and DELETE are 405 without a token", %{conn: conn} do
      for conn <- [get(conn, "/mcp"), delete(build_conn(), "/mcp")] do
        assert_matches ^strict_map(%{
                         "error" => "method_not_allowed",
                         "error_description" => ^any(:string)
                       }) = json_response(conn, 405)
      end
    end
  end

  describe "envelope validation" do
    setup :insert_token

    test "rejects a protocol version header disagreeing with the body", %{conn: conn, token: t} do
      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" =>
                             "Mcp-Protocol-Version header does not match _meta protocolVersion"
                         })
                     }) =
                       conn
                       |> mcp_post(t, "tools/list", header_version: "2025-11-25")
                       |> json_response(400)
    end

    test "rejects a method header disagreeing with the body", %{conn: conn, token: t} do
      conn = conn |> mcp_post(t, "tools/list", header_method: "server/discover")

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => ^any(:string)
                         })
                     }) = json_response(conn, 400)
    end

    test "rejects an Mcp-Name disagreeing with params.name", %{conn: conn, token: t} do
      conn =
        conn
        |> mcp_post(t, "tools/call",
          params: %{"name" => "list_sites", "arguments" => %{}},
          header_name: "something_else"
        )

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => ^~r/Mcp-Name/
                         })
                     }) =
                       conn
                       |> json_response(400)
    end

    test "accepts a base64-encoded Mcp-Name", %{conn: conn, token: t} do
      encoded = "=?base64?" <> Base.encode64("list_sites") <> "?="

      resp =
        conn
        |> mcp_post(t, "tools/call",
          params: %{"name" => "list_sites", "arguments" => %{}},
          header_name: encoded
        )
        |> json_response(200)

      assert resp["result"]["isError"] == false
    end

    test "rejects a missing header", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> post("/mcp", body("tools/list", []))

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => ^~r/mcp-method/
                         })
                     }) =
                       conn
                       |> json_response(400)
    end

    test "rejects a missing _meta protocol version", %{conn: conn, token: t} do
      payload = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/list",
        "params" => %{"_meta" => %{"io.modelcontextprotocol/clientCapabilities" => %{}}}
      }

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_602,
                           "message" => ^~r/protocolVersion/
                         })
                     }) =
                       conn
                       |> put_req_header("authorization", "Bearer " <> t)
                       |> put_req_header("mcp-protocol-version", @version)
                       |> put_req_header("mcp-method", "tools/list")
                       |> post("/mcp", payload)
                       |> json_response(400)
    end

    test "rejects an unsupported version, naming what is supported", %{conn: conn, token: t} do
      conn =
        conn
        |> mcp_post(t, "tools/list",
          meta_version: "1999-01-01",
          header_version: "1999-01-01"
        )

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_022,
                           "message" => ^any(:string),
                           "data" =>
                             ^strict_map(%{
                               "supported" => ^[@version],
                               "requested" => "1999-01-01"
                             })
                         })
                     }) =
                       conn
                       |> json_response(400)
    end

    test "rejects a non-object params", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => "not-an-object"
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" => ^strict_map(%{"code" => -32_602, "message" => ^any(:string)})
                     }) =
                       conn
                       |> json_response(400)
    end

    test "rejects a non-object _meta", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{"_meta" => "not-an-object"}
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" => ^strict_map(%{"code" => -32_602, "message" => ^any(:string)})
                     }) =
                       conn
                       |> json_response(400)
    end

    test "rejects a batch array, with or without a token", %{conn: conn, token: t} do
      for auth <- [[{"authorization", "Bearer " <> t}], []] do
        assert_matches ^strict_map(%{
                         "jsonrpc" => "2.0",
                         "id" => nil,
                         "error" =>
                           ^strict_map(%{
                             "code" => -32_600,
                             "message" => ^any(:string)
                           })
                       }) =
                         Enum.reduce(auth, recycle(conn), fn {k, v}, c ->
                           put_req_header(c, k, v)
                         end)
                         |> put_req_header("mcp-protocol-version", @version)
                         |> put_req_header("mcp-method", "tools/list")
                         |> put_req_header("content-type", "application/json")
                         |> post("/mcp", Jason.encode!([body("tools/list", [])]))
                         |> json_response(400)
      end
    end
  end

  describe "protocol methods" do
    setup :insert_token

    # The spec asks servers to identify themselves in each result's `_meta`.
    test "every result identifies the server", %{conn: conn, token: t} do
      for method <- ~w(server/discover tools/list) do
        assert_matches ^strict_map(%{
                         "io.modelcontextprotocol/serverInfo" =>
                           ^strict_map(%{
                             "name" => ^Plausible.product_name(),
                             "version" => ^any(:string)
                           })
                       }) =
                         conn
                         |> recycle()
                         |> mcp_post(t, method)
                         |> json_response(200)
                         |> get_in(["result", "_meta"])
      end
    end

    test "server/discover advertises versions and the tools capability", %{conn: conn, token: t} do
      resp = conn |> mcp_post(t, "server/discover") |> json_response(200)

      assert resp["result"]["supportedVersions"] == [@version]
      assert resp["result"]["capabilities"] == %{"tools" => %{}}
      assert resp["result"]["instructions"] =~ "list_sites"
    end

    test "tools/list returns list_sites", %{conn: conn, token: t} do
      resp = conn |> mcp_post(t, "tools/list") |> json_response(200)

      assert [tool] = resp["result"]["tools"]
      assert tool["name"] == "list_sites"
      assert tool["inputSchema"]["type"] == "object"
    end

    # Results of cacheable operations must carry caching hints. Omitting them
    # fails schema validation on the client, which connects and then fails to
    # fetch any tool.
    test "cacheable results carry ttlMs and cacheScope", %{conn: conn, token: t} do
      for method <- ~w(server/discover tools/list) do
        result =
          conn |> recycle() |> mcp_post(t, method) |> json_response(200) |> Map.fetch!("result")

        assert is_integer(result["ttlMs"]) and result["ttlMs"] >= 0,
               "#{method} must carry a non-negative integer ttlMs"

        assert result["cacheScope"] in ["public", "private"],
               "#{method} must carry a valid cacheScope"
      end
    end

    test "non-cacheable results carry no caching hints", %{conn: conn, token: t} do
      result = conn |> call_tool(t, "list_sites") |> json_response(200) |> Map.fetch!("result")

      refute Map.has_key?(result, "ttlMs")
      refute Map.has_key?(result, "cacheScope")
    end

    test "a notification is an invalid request - this revision defines none", %{
      conn: conn,
      token: t
    } do
      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => nil,
                       "error" =>
                         ^strict_map(%{"code" => -32_600, "message" => "Invalid Request"})
                     }) =
                       conn
                       |> mcp_post(t, "notifications/progress", id: false)
                       |> json_response(400)
    end

    test "an unknown method is 404 with -32601", %{conn: conn, token: t} do
      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_601,
                           "message" => "Method not found"
                         })
                     }) = conn |> mcp_post(t, "resources/list") |> json_response(404)
    end
  end

  describe "tools/call list_sites" do
    setup :insert_token

    test "returns the team's sites", %{conn: conn, user: user, token: t} do
      site = new_site(owner: user)

      resp = conn |> call_tool(t, "list_sites") |> json_response(200)

      assert resp["result"]["isError"] == false
      assert %{"sites" => [returned]} = tool_payload(resp)
      assert returned["domain"] == site.domain
      assert returned["timezone"] == site.timezone
    end

    test "returns an empty list when the team has no sites", %{conn: conn, token: t} do
      resp = conn |> call_tool(t, "list_sites") |> json_response(200)
      assert tool_payload(resp) == %{"sites" => []}
    end

    test "does not leak another team's sites", %{conn: conn, user: user, token: t} do
      mine = new_site(owner: user)
      _theirs = new_site(owner: new_user())

      resp = conn |> call_tool(t, "list_sites") |> json_response(200)

      assert %{"sites" => [only]} = tool_payload(resp)
      assert only["domain"] == mine.domain
    end

    test "a grant lacking sites:read is 403, challenging for the scope it needs", %{
      conn: conn,
      user: user,
      team: team
    } do
      new_site(owner: user)

      token = Token.generate(:access).raw

      insert(:oauth_grant,
        user: user,
        team: team,
        access_token: token,
        scopes: [Scopes.stats_read()]
      )

      conn = call_tool(conn, token, "list_sites")

      assert_matches ^strict_map(%{"error" => "insufficient_scope"}) = json_response(conn, 403)

      assert [challenge] = get_resp_header(conn, "www-authenticate")
      assert challenge =~ ~s(error="insufficient_scope")
      assert challenge =~ ~s(scope="#{Scopes.sites_read()}")
      assert challenge =~ ~s(resource_metadata="#{PlausibleWeb.Endpoint.url()}/)
    end

    # The roles the tool declares have to match what listing sites actually
    # allows, so each one is exercised rather than assumed.
    test "serves every role the tool declares", %{conn: conn, user: owner, team: team} do
      site = new_site(owner: owner)

      for role <- [:viewer, :billing, :editor, :admin] do
        member = add_member(team, role: role)
        member_token = Token.generate(:access).raw
        insert(:oauth_grant, user: member, team: team, access_token: member_token)

        resp =
          conn
          |> recycle()
          |> call_tool(member_token, "list_sites")
          |> json_response(200)

        assert resp["result"]["isError"] == false, "#{role} should be able to list sites"
        assert %{"sites" => [returned]} = tool_payload(resp)
        assert returned["domain"] == site.domain
      end
    end

    test "an unknown tool is a protocol error, not a tool error", %{conn: conn, token: t} do
      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_602,
                           "message" => "Unknown tool"
                         })
                     }) = conn |> call_tool(t, "made_up_tool") |> json_response(400)
    end
  end

  defp insert_token(%{user: user, team: team}) do
    token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: token)

    {:ok, token: token}
  end

  defp body(method, opts) do
    params =
      opts
      |> Keyword.get(:params, %{})
      |> Map.put("_meta", %{
        "io.modelcontextprotocol/protocolVersion" => Keyword.get(opts, :meta_version, @version),
        "io.modelcontextprotocol/clientCapabilities" => %{}
      })

    base = %{"jsonrpc" => "2.0", "method" => method, "params" => params}
    if Keyword.get(opts, :id, 1), do: Map.put(base, "id", 1), else: base
  end

  # Mirrors the body into the headers the transport requires, so a test describes
  # a conforming client unless it deliberately diverges.
  defp mcp_post(conn, token, method, opts \\ []) do
    payload = body(method, opts)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("mcp-protocol-version", Keyword.get(opts, :header_version, @version))
      |> put_req_header("mcp-method", Keyword.get(opts, :header_method, method))

    conn =
      case Keyword.get(opts, :header_name, get_in(payload, ["params", "name"])) do
        nil -> conn
        name -> put_req_header(conn, "mcp-name", name)
      end

    post(conn, "/mcp", payload)
  end

  defp call_tool(conn, token, name, args \\ %{}) do
    mcp_post(conn, token, "tools/call", params: %{"name" => name, "arguments" => args})
  end

  defp tool_payload(resp) do
    assert [%{"type" => "text", "text" => text}] = resp["result"]["content"]
    Jason.decode!(text)
  end
end
