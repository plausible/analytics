defmodule PlausibleWeb.MCP.MCPControllerTest do
  # Not `async: true`: the end-to-end flow stubs the CIMD fetch and its DNS lookup.
  use PlausibleWeb.ConnCase
  use Plausible.Test.Support.DNS

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth
  alias Plausible.OAuth.{ProtectedResources, Token}

  @version "2026-07-28"

  setup [:create_user, :create_team]

  describe "authentication" do
    test "401s without a token, pointing at metadata that actually resolves", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "unauthorized"}) = json_response(conn, 401)

      assert [challenge] = get_resp_header(conn, "www-authenticate")
      assert [_, metadata_url] = Regex.run(~r/resource_metadata="([^"]+)"/, challenge)

      metadata = build_conn() |> get(URI.parse(metadata_url).path) |> json_response(200)

      assert_matches ^strict_map(%{
                       "resource" =>
                         ^ProtectedResources.get_resource_url(ProtectedResources.mcp()),
                       "authorization_servers" => [^PlausibleWeb.Endpoint.url()],
                       "scopes_supported" => ^ProtectedResources.mcp().scopes_supported,
                       "bearer_methods_supported" => ["header"]
                     }) = metadata
    end

    test "tools/call requires a token too", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "unauthorized"}) = json_response(conn, 401)
    end

    test "401s an unknown token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-token")
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
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

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(conn, 401)
    end

    test "a malformed request on a method needing no token is 400, not a crash", %{conn: conn} do
      conn =
        conn
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
  end

  describe "envelope validation" do
    setup :insert_token

    test "rejects a protocol version header disagreeing with the body", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", "2025-11-25")
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" =>
                             "Mcp-Protocol-Version header does not match _meta protocolVersion"
                         })
                     }) = json_response(conn, 400)
    end

    test "rejects a method header disagreeing with the body", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "server/discover")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => "Mcp-Method header does not match request method"
                         })
                     }) = json_response(conn, 400)
    end

    test "rejects an Mcp-Name disagreeing with params.name", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "something_else")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => "Mcp-Name header does not match params.name"
                         })
                     }) = json_response(conn, 400)
    end

    test "accepts a base64-encoded Mcp-Name", %{conn: conn, token: t} do
      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "=?base64?" <> Base.encode64("list_sites") <> "?=")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "content" => [
                             ^strict_map(%{
                               "type" => "text",
                               "text" => ^JSON.encode!(%{sites: []})
                             })
                           ],
                           "isError" => false,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             })
                         })
                     }) = resp
    end

    test "rejects a missing header", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_020,
                           "message" => "Missing required header: mcp-method"
                         })
                     }) = json_response(conn, 400)
    end

    test "rejects a missing _meta protocol version", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{"io.modelcontextprotocol/clientCapabilities" => %{}}
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_602,
                           "message" =>
                             "Missing or invalid _meta field: io.modelcontextprotocol/protocolVersion"
                         })
                     }) = json_response(conn, 400)
    end

    test "rejects an unsupported version, naming what is supported", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", "1999-01-01")
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => "1999-01-01",
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{
                           "code" => -32_022,
                           "message" => "Unsupported protocol version",
                           "data" =>
                             ^strict_map(%{
                               "supported" => ^[@version],
                               "requested" => "1999-01-01"
                             })
                         })
                     }) = json_response(conn, 400)
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
                     }) = json_response(conn, 400)
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
                     }) = json_response(conn, 400)
    end

    test "rejects a batch array with a token", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> put_req_header("content-type", "application/json")
        |> post(
          "/mcp",
          JSON.encode!([
            %{
              "jsonrpc" => "2.0",
              "id" => 1,
              "method" => "tools/list",
              "params" => %{
                "_meta" => %{
                  "io.modelcontextprotocol/protocolVersion" => @version,
                  "io.modelcontextprotocol/clientCapabilities" => %{}
                }
              }
            }
          ])
        )

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => nil,
                       "error" =>
                         ^strict_map(%{"code" => -32_600, "message" => "Invalid Request"})
                     }) = json_response(conn, 400)
    end

    test "rejects a batch array without a token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> put_req_header("content-type", "application/json")
        |> post(
          "/mcp",
          JSON.encode!([
            %{
              "jsonrpc" => "2.0",
              "id" => 1,
              "method" => "tools/list",
              "params" => %{
                "_meta" => %{
                  "io.modelcontextprotocol/protocolVersion" => @version,
                  "io.modelcontextprotocol/clientCapabilities" => %{}
                }
              }
            }
          ])
        )

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => nil,
                       "error" =>
                         ^strict_map(%{"code" => -32_600, "message" => "Invalid Request"})
                     }) = json_response(conn, 400)
    end

    test "a notification is an invalid request - this revision defines none", %{
      conn: conn,
      token: t
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "notifications/progress")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "method" => "notifications/progress",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => nil,
                       "error" =>
                         ^strict_map(%{"code" => -32_600, "message" => "Invalid Request"})
                     }) = json_response(conn, 400)
    end
  end

  describe "server/discover" do
    # A client picks a protocol version before it holds a token, and a bare 401
    # tells it nothing about which versions the server speaks.
    test "advertises versions, the tools capability and the server, without a token", %{
      conn: conn
    } do
      resp =
        conn
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "server/discover")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "server/discover",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "supportedVersions" => ^[@version],
                           "capabilities" => ^strict_map(%{"tools" => ^strict_map(%{})}),
                           "instructions" => ^~r/list_sites/,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             }),
                           "ttlMs" => ^any(:pos_integer),
                           "cacheScope" => "public"
                         })
                     }) = resp
    end
  end

  describe "tools/list" do
    setup :insert_token

    test "returns list_sites, with caching hints and the server identity", %{conn: conn, token: t} do
      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "tools" => [
                             ^strict_map(%{
                               "name" => "list_sites",
                               "description" => ^any(:string),
                               "inputSchema" =>
                                 ^strict_map(%{
                                   "type" => "object",
                                   "properties" => ^strict_map(%{}),
                                   "additionalProperties" => false
                                 })
                             })
                           ],
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             }),
                           "ttlMs" => ^any(:pos_integer),
                           "cacheScope" => "public"
                         })
                     }) = resp
    end
  end

  describe "tools/call" do
    setup :insert_token

    test "an unknown tool is a protocol error, not a tool error", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "made_up_tool")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "made_up_tool",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" => ^strict_map(%{"code" => -32_602, "message" => "Unknown tool"})
                     }) = json_response(conn, 400)
    end
  end

  describe "tools/call list_sites" do
    setup :insert_token

    test "returns the team's sites", %{conn: conn, user: user, token: t} do
      site = new_site(owner: user)

      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "content" => [
                             ^strict_map(%{
                               "type" => "text",
                               "text" =>
                                 ^JSON.encode!(%{
                                   sites: [%{domain: site.domain, timezone: site.timezone}]
                                 })
                             })
                           ],
                           "isError" => false,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             })
                         })
                     }) = resp
    end

    test "returns an empty list when the team has no sites", %{conn: conn, token: t} do
      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "content" => [
                             ^strict_map(%{
                               "type" => "text",
                               "text" => ^JSON.encode!(%{sites: []})
                             })
                           ],
                           "isError" => false,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             })
                         })
                     }) = resp
    end

    test "does not leak another team's sites", %{conn: conn, user: user, token: t} do
      mine = new_site(owner: user)
      _theirs = new_site(owner: new_user())

      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "content" => [
                             ^strict_map(%{
                               "type" => "text",
                               "text" =>
                                 ^JSON.encode!(%{
                                   sites: [%{domain: mine.domain, timezone: mine.timezone}]
                                 })
                             })
                           ],
                           "isError" => false,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             })
                         })
                     }) = resp
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

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "insufficient_scope"}) = json_response(conn, 403)

      assert [challenge] = get_resp_header(conn, "www-authenticate")

      assert challenge ==
               ~s(Bearer resource_metadata="#{PlausibleWeb.Endpoint.url()}/.well-known/oauth-protected-resource/mcp", scope="#{Scopes.sites_read()}", error="insufficient_scope")
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
          |> put_req_header("authorization", "Bearer " <> member_token)
          |> put_req_header("mcp-protocol-version", @version)
          |> put_req_header("mcp-method", "tools/call")
          |> put_req_header("mcp-name", "list_sites")
          |> post("/mcp", %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "tools/call",
            "params" => %{
              "name" => "list_sites",
              "arguments" => %{},
              "_meta" => %{
                "io.modelcontextprotocol/protocolVersion" => @version,
                "io.modelcontextprotocol/clientCapabilities" => %{}
              }
            }
          })
          |> json_response(200)

        assert_matches ^strict_map(%{
                         "jsonrpc" => "2.0",
                         "id" => 1,
                         "result" =>
                           ^strict_map(%{
                             "content" => [
                               ^strict_map(%{
                                 "type" => "text",
                                 "text" =>
                                   ^JSON.encode!(%{
                                     sites: [%{domain: site.domain, timezone: site.timezone}]
                                   })
                               })
                             ],
                             "isError" => false,
                             "resultType" => "complete",
                             "_meta" =>
                               ^strict_map(%{
                                 "io.modelcontextprotocol/serverInfo" =>
                                   ^strict_map(%{
                                     "name" => ^Plausible.product_name(),
                                     "version" => ^any(:string)
                                   })
                               })
                           })
                       }) = resp
      end
    end
  end

  describe "unknown method" do
    setup :insert_token

    test "is 404 with -32601", %{conn: conn, token: t} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> t)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "resources/list")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "resources/list",
          "params" => %{
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "error" =>
                         ^strict_map(%{"code" => -32_601, "message" => "Method not found"})
                     }) = json_response(conn, 404)
    end
  end

  # These only ever answer 405, so they stay unauthenticated - a 401 would hide
  # the signal an older client uses to detect the protocol revision.
  describe "GET /mcp and DELETE /mcp" do
    test "GET is 405 without a token", %{conn: conn} do
      assert_matches ^strict_map(%{
                       "error" => "method_not_allowed",
                       "error_description" => "Use POST for MCP."
                     }) = conn |> get("/mcp") |> json_response(405)
    end

    test "DELETE is 405 without a token", %{conn: conn} do
      assert_matches ^strict_map(%{
                       "error" => "method_not_allowed",
                       "error_description" => "Use POST for MCP."
                     }) = conn |> delete("/mcp") |> json_response(405)
    end
  end

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
          JSON.encode!(%{
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

      resp =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> access_token)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "jsonrpc" => "2.0",
                       "id" => 1,
                       "result" =>
                         ^strict_map(%{
                           "content" => [
                             ^strict_map(%{
                               "type" => "text",
                               "text" =>
                                 ^JSON.encode!(%{
                                   sites: [%{domain: site.domain, timezone: site.timezone}]
                                 })
                             })
                           ],
                           "isError" => false,
                           "resultType" => "complete",
                           "_meta" =>
                             ^strict_map(%{
                               "io.modelcontextprotocol/serverInfo" =>
                                 ^strict_map(%{
                                   "name" => ^Plausible.product_name(),
                                   "version" => ^any(:string)
                                 })
                             })
                         })
                     }) = resp

      {:ok, grant, _role} = OAuth.find_access_token(access_token, ProtectedResources.mcp())
      OAuth.revoke_grant(grant)

      revoked =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> access_token)
        |> put_req_header("mcp-protocol-version", @version)
        |> put_req_header("mcp-method", "tools/call")
        |> put_req_header("mcp-name", "list_sites")
        |> post("/mcp", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{
            "name" => "list_sites",
            "arguments" => %{},
            "_meta" => %{
              "io.modelcontextprotocol/protocolVersion" => @version,
              "io.modelcontextprotocol/clientCapabilities" => %{}
            }
          }
        })

      assert_matches ^strict_map(%{"error" => "invalid_token"}) = json_response(revoked, 401)
    end
  end

  defp insert_token(%{user: user, team: team}) do
    token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: token)

    {:ok, token: token}
  end
end
