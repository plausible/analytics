defmodule PlausibleWeb.MCP.ConformanceTest do
  @moduledoc """
  Tests our `/mcp` server against the official MCP conformance suite
  (https://github.com/modelcontextprotocol/conformance) and against real
  clients from the TypeScript SDK v1 and v2.

  There are two kinds of tests:

    * Suite tests run the conformance suite.
    * SDK tests run `conformance/client.mjs`. The script uses the official MCP
      TS client to call the `list_sites` tool.

  The suite runs once for each protocol version that we support.
  When you add a version, add it to the list of versions below.

  We do not support some MCP features, e.g. resources and logging.
  `conformance/expected-failures.yml` lists the scenarios for these features.
  When you add a feature, remove its scenarios from this file.

  The tests need Docker. They have the `:mcp_conformance` tag, so they do not
  run by default. To run them:

      mix test test/plausible_web/controllers/mcp/conformance_test.exs --include mcp_conformance
  """

  use PlausibleWeb.ConnCase, async: false

  alias Plausible.OAuth.Token

  @moduletag :mcp_conformance

  @image "plausible-mcp-conformance"
  @dir Path.expand("conformance", __DIR__)

  defmodule AuthorizedEndpoint do
    @endpoint_opts PlausibleWeb.Endpoint.init([])

    def init(token), do: token

    def call(conn, token) do
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> PlausibleWeb.Endpoint.call(@endpoint_opts)
    end
  end

  setup_patch_env(PlausibleWeb.Api.RateLimit,
    legacy_per_user_hourly_request_limit: 600,
    burst_request_limit: 10_000,
    burst_period_seconds: 10
  )

  setup_all do
    {output, status} =
      System.cmd("docker", ["build", "--quiet", "--tag", @image, @dir], stderr_to_stdout: true)

    assert status == 0, output
    :ok
  end

  setup [:create_user, :create_team, :insert_token, :start_server]

  for version <- ["2026-07-28", "2025-11-25"] do
    test "meets the #{version} requirements", %{url: url} do
      {output, status} =
        docker_run([
          "conformance",
          "server",
          "--url",
          url,
          "--requirements",
          unquote(version),
          "--expected-failures",
          "expected-failures.yml"
        ])

      assert status == 0, output
    end
  end

  for sdk <- ["v1", "v2"] do
    test "the TS SDK #{sdk} client connects and calls a tool", %{url: url} do
      {output, status} = docker_run(["node", "client.mjs", unquote(sdk), url])

      assert status == 0, output
    end
  end

  defp docker_run(command) do
    System.cmd(
      "docker",
      [
        "run",
        "--rm",
        "--init",
        "--network",
        "host",
        "--read-only",
        @image
      ] ++ command,
      stderr_to_stdout: true
    )
  end

  defp insert_token(%{user: user, team: team}) do
    token = Token.generate(:access).raw
    insert(:oauth_grant, user: user, team: team, access_token: token)

    {:ok, token: token}
  end

  defp start_server(%{token: token}) do
    start_supervised!(
      {Plug.Cowboy,
       scheme: :http,
       plug: {AuthorizedEndpoint, token},
       options: [ip: {127, 0, 0, 1}, port: 0, ref: __MODULE__]}
    )

    {ip, port} = :ranch.get_addr(__MODULE__)
    {:ok, url: "http://#{:inet.ntoa(ip)}:#{port}/mcp"}
  end
end
