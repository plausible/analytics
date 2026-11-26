defmodule PlausibleWeb.APITraceAttributesTest do
  use PlausibleWeb.ConnCase, async: false

  require Record

  Record.defrecordp(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))

  require OpenTelemetry.Tracer, as: Tracer

  setup do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
    :ok
  end

  describe "Stats API" do
    test "traces the credential and site" do
      user = new_user()
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, site, 200)

      assert attributes["plausible.user.id"] == user.id
      assert attributes["plausible.team.id"] == api_key.team_id
      assert attributes["plausible.credential.type"] == "api_key"
      assert attributes["plausible.credential.id"] == api_key.id
      assert attributes["plausible.credential.label"] == api_key.key_prefix
      assert attributes["plausible.site.id"] == site.id
      assert attributes["plausible.tool"] == "query_stats"
    end

    test "traces the team of the site for a legacy API key" do
      user = new_user()
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user)

      attributes = trace_query(api_key, site, 200)

      assert attributes["plausible.team.id"] == site.team_id
    end

    test "does not trace the team of a site a legacy API key cannot access" do
      api_key = insert(:api_key, user: new_user())
      site = new_site()

      attributes = trace_query(api_key, site, 401)

      refute Map.has_key?(attributes, "plausible.team.id")
    end

    test "traces the error code of a site the API key cannot access" do
      user = new_user()
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, new_site(), 401)

      assert attributes["plausible.error.code"] == :site_not_found
    end

    test "traces the error code of a site that does not exist" do
      user = new_user()
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, %{domain: "missing.example.com"}, 401)

      assert attributes["plausible.error.code"] == :site_not_found
    end

    test "traces the tool of a request that fails authorization" do
      attributes =
        trace(fn ->
          build_conn()
          |> put_req_header("authorization", "Bearer invalid")
          |> post("/api/v2/query", query_params(new_site(), %{}))
          |> json_response(401)
        end)

      assert attributes["plausible.tool"] == "query_stats"
    end

    test "traces the error code of an invalid query" do
      user = new_user()
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, site, 400, %{"filters" => [["bad"]]})

      assert attributes["plausible.error.code"] == :failed_schema_validation
    end

    @tag :capture_log
    test "traces the credential on rate-limited requests" do
      user = new_user(team: [hourly_api_request_limit: 0])
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, site, 429)

      assert attributes["plausible.user.id"] == user.id
      assert attributes["plausible.credential.id"] == api_key.id
      assert attributes["plausible.error.code"] == :rate_limit_hourly
    end

    @tag :capture_log
    test "traces the error code on burst-limited requests" do
      patch_env(PlausibleWeb.Api.RateLimit,
        legacy_per_user_hourly_request_limit: 600,
        burst_request_limit: 0,
        burst_period_seconds: 10
      )

      user = new_user()
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, site, 429)

      assert attributes["plausible.error.code"] == :rate_limit_burst
    end
  end

  on_ee do
    describe "Sites API" do
      test "traces the credential on the sites list" do
        user = new_user()
        api_key = insert(:api_key, user: user, team: team_of(user), scopes: ["sites:read:*"])

        attributes =
          trace(fn ->
            build_conn()
            |> put_req_header("authorization", "Bearer #{api_key.key}")
            |> get("/api/v1/sites")
            |> json_response(200)
          end)

        assert attributes["plausible.user.id"] == user.id
        assert attributes["plausible.team.id"] == api_key.team_id
        assert attributes["plausible.credential.type"] == "api_key"
        assert attributes["plausible.credential.id"] == api_key.id
        assert attributes["plausible.credential.label"] == api_key.key_prefix
        assert attributes["plausible.tool"] == "list_sites"
      end

      test "traces the error code of an API key without the required scope" do
        user = new_user()
        api_key = insert(:api_key, user: user, team: team_of(user), scopes: ["stats:read:*"])

        attributes =
          trace(fn ->
            build_conn()
            |> put_req_header("authorization", "Bearer #{api_key.key}")
            |> post("/api/v1/sites", %{"domain" => "new.example.com"})
            |> json_response(401)
          end)

        assert attributes["plausible.error.code"] == :insufficient_scope
      end
    end
  end

  describe "MCP" do
    test "traces the OAuth credential and tool" do
      user = new_user()
      site = new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw

      grant =
        insert(:oauth_grant,
          user: user,
          team: team_of(user),
          access_token: token,
          client_name: "Claude"
        )

      attributes =
        trace_tool_call(token, "query_stats", 200, %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all"
        })

      assert attributes["plausible.user.id"] == user.id
      assert attributes["plausible.team.id"] == grant.team_id
      assert attributes["plausible.credential.type"] == "oauth_grant"
      assert attributes["plausible.credential.id"] == grant.id
      assert attributes["plausible.credential.label"] == "Claude"
      assert attributes["plausible.site.id"] == site.id
      assert attributes["plausible.tool"] == "query_stats"
    end

    test "does not trace an unknown tool name" do
      user = new_user()
      new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw
      insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes = trace_tool_call(token, "unknown_tool", 400, %{})

      refute Map.has_key?(attributes, "plausible.tool")
    end

    @tag :capture_log
    test "traces the credential and error code on rate-limited requests" do
      user = new_user(team: [hourly_api_request_limit: 0])
      token = Plausible.OAuth.Token.generate(:access).raw

      grant =
        insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes = trace_tool_call(token, "list_sites", 200, %{})

      assert attributes["plausible.credential.id"] == grant.id
      assert attributes["plausible.error.code"] == :rate_limit_hourly
    end

    @tag :capture_log
    test "traces the error code on burst-limited tool calls" do
      patch_env(PlausibleWeb.Api.RateLimit,
        legacy_per_user_hourly_request_limit: 600,
        burst_request_limit: 0,
        burst_period_seconds: 10
      )

      user = new_user()
      new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw
      insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes = trace_tool_call(token, "list_sites", 200, %{})

      assert attributes["plausible.error.code"] == :rate_limit_burst
    end

    @tag :capture_log
    test "traces the error code on burst-limited requests that are not tool calls" do
      patch_env(PlausibleWeb.Api.RateLimit,
        legacy_per_user_hourly_request_limit: 600,
        burst_request_limit: 0,
        burst_period_seconds: 10
      )

      user = new_user()
      new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw
      insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes =
        trace(fn ->
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> put_req_header("mcp-protocol-version", "2025-11-25")
          |> post("/mcp", %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"})
          |> json_response(429)
        end)

      assert attributes["plausible.error.code"] == :rate_limit_burst
    end

    test "traces the same error code as the Stats API for an invalid query" do
      user = new_user()
      site = new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw
      insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes =
        trace_tool_call(token, "query_stats", 200, query_params(site, %{"filters" => [["bad"]]}))

      assert attributes["plausible.error.code"] == :failed_schema_validation
    end

    test "traces the same error code as the Stats API for a site the grant cannot access" do
      user = new_user()
      new_site(owner: user)
      token = Plausible.OAuth.Token.generate(:access).raw
      insert(:oauth_grant, user: user, team: team_of(user), access_token: token)

      attributes = trace_tool_call(token, "query_stats", 200, query_params(new_site(), %{}))

      assert attributes["plausible.error.code"] == :site_not_found
    end
  end

  defp trace_tool_call(token, name, status, arguments) do
    trace(fn ->
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("mcp-protocol-version", "2026-07-28")
      |> put_req_header("mcp-method", "tools/call")
      |> put_req_header("mcp-name", name)
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => %{
          "name" => name,
          "arguments" => arguments,
          "_meta" => %{
            "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
            "io.modelcontextprotocol/clientCapabilities" => %{}
          }
        }
      })
      |> json_response(status)
    end)
  end

  defp trace_query(api_key, site, status, params \\ %{}) do
    trace(fn ->
      build_conn()
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> post("/api/v2/query", query_params(site, params))
      |> json_response(status)
    end)
  end

  defp query_params(site, params) do
    Map.merge(
      %{"site_id" => site.domain, "metrics" => ["visitors"], "date_range" => "all"},
      params
    )
  end

  defp trace(request) do
    span_id =
      Tracer.with_span "test request" do
        request.()
        OpenTelemetry.Span.span_id(Tracer.current_span_ctx())
      end

    assert_receive {:span, span(span_id: ^span_id, attributes: attributes)}
    :otel_attributes.map(attributes)
  end
end
