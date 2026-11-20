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

    @tag :capture_log
    test "traces the credential on rate-limited requests" do
      user = new_user(team: [hourly_api_request_limit: 0])
      site = new_site(owner: user)
      api_key = insert(:api_key, user: user, team: team_of(user))

      attributes = trace_query(api_key, site, 429)

      assert attributes["plausible.user.id"] == user.id
      assert attributes["plausible.credential.id"] == api_key.id
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
      end
    end
  end

  defp trace_query(api_key, site, status) do
    trace(fn ->
      build_conn()
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> post("/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all"
      })
      |> json_response(status)
    end)
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
