defmodule PlausibleWeb.MCP.MCPController do
  @moduledoc """
  Model Context Protocol (MCP) endpoint over Streamable HTTP, implementing the
  stateless `2026-07-28` revision of the protocol.

  The protocol is stateless: there is no `initialize` handshake and no
  `Mcp-Session-Id`. Every request is self-describing and independent, so any
  request can be served by any instance behind a plain load balancer. Each
  request carries its protocol version, client identity and capabilities in
  `params._meta` (the `io.modelcontextprotocol/*` keys), mirrored into the
  `MCP-Protocol-Version`, `Mcp-Method` and (for `tools/call`) `Mcp-Name` HTTP
  headers so intermediaries can route without parsing the body. A `Mcp-Session-Id`
  or `Last-Event-ID` sent by a client is ignored and never echoed.

  Responses are returned directly as `application/json`; the optional SSE
  transport, MRTR and subscriptions are not implemented. `GET`/`DELETE /mcp`
  return `405`, and an unknown JSON-RPC method returns `404` with `-32601`.

  Supported methods: `server/discover`, `ping`, `tools/list`, `tools/call` and
  `notifications/*` (acknowledged with `202`). Two tools are exposed:

    * `list_sites` - the sites of the token's bound team (scope `sites:read:*`).
    * `query_stats` - wraps the Stats API `POST /api/v2/query` (scope
      `stats:read:*`).

  Authentication, rate limiting and `current_user`/`current_team` assignment are
  handled upstream by `PlausibleWeb.Plugs.AuthorizeOAuthAPI`. `Origin` validation
  is intentionally not performed: DNS-rebinding protection targets locally-bound
  servers, and this is a public, bearer-authenticated remote endpoint.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Stats.{Query, QueryError}

  @supported_versions ["2026-07-28"]
  @server_name "Plausible Analytics"

  @version_key "io.modelcontextprotocol/protocolVersion"
  @caps_key "io.modelcontextprotocol/clientCapabilities"
  @server_info_key "io.modelcontextprotocol/serverInfo"

  @tools [
    %{
      name: "list_sites",
      description:
        "List the sites (websites) the authorized team has access to. Returns each site's domain and timezone.",
      inputSchema: %{
        type: "object",
        properties: %{},
        additionalProperties: false
      }
    },
    %{
      name: "query_stats",
      description:
        "Query analytics for a site using the Plausible Stats API v2. Provide the site's domain as `site_id`, the `metrics` to compute, and a `date_range`. Optionally provide `dimensions`, `filters`, `order_by` and other Stats API v2 query fields.",
      inputSchema: %{
        type: "object",
        properties: %{
          site_id: %{
            type: "string",
            description: "The domain of the site to query, e.g. \"example.com\"."
          },
          metrics: %{
            type: "array",
            items: %{type: "string"},
            description: "List of metrics, e.g. [\"visitors\", \"pageviews\"]."
          },
          date_range: %{
            description:
              "A named range like \"7d\", \"30d\", \"month\", \"all\", or a [start, end] ISO-8601 pair."
          },
          dimensions: %{type: "array", items: %{type: "string"}},
          filters: %{type: "array"},
          order_by: %{type: "array"},
          include: %{type: "object"},
          pagination: %{type: "object"}
        },
        required: ["site_id", "metrics", "date_range"]
      }
    }
  ]

  ## Streamable HTTP transport

  def handle(conn, _params) do
    case conn.body_params do
      %{"jsonrpc" => "2.0", "method" => method} = message ->
        # A message with an `id` is a request; without one it is a notification,
        # acknowledged with `202` and no body. Notification POSTs carry no
        # per-request metadata requirements in this revision.
        if Map.has_key?(message, "id") do
          handle_request(conn, message, method)
        else
          send_resp(conn, 202, "")
        end

      _ ->
        # Not a single JSON-RPC object (e.g. a batch array parsed as `_json`).
        send_json(conn, 400, error_response(nil, -32_600, "Invalid Request"))
    end
  end

  def not_supported(conn, _params) do
    send_json(conn, 405, error_response(nil, -32_600, "Method not allowed. Use POST for MCP."))
  end

  # Validate the request envelope (headers mirrored from the body, required
  # `_meta` fields, protocol version and client capabilities) before dispatching.
  # The first failing check short-circuits with its HTTP status and JSON-RPC error.
  defp handle_request(conn, message, method) do
    id = message["id"]
    meta = meta(message)

    with :ok <- validate_headers_present(conn, method),
         :ok <- validate_meta_fields(meta),
         :ok <- validate_header_body_match(conn, message, method, meta),
         :ok <- validate_version(meta),
         :ok <- validate_capabilities(method, meta) do
      {status, body} = dispatch(conn, id, method, message)
      send_json(conn, status, body)
    else
      {:error, status, code, error_message, data} ->
        send_json(conn, status, error_response(id, code, error_message, data))
    end
  end

  ## Request envelope validation

  defp validate_headers_present(conn, method) do
    required = ["mcp-protocol-version", "mcp-method"] ++ name_header(method)

    case Enum.find(required, fn header -> header(conn, header) == nil end) do
      nil -> :ok
      missing -> header_mismatch("Missing required header: #{missing}")
    end
  end

  defp validate_meta_fields(meta) do
    cond do
      not is_binary(meta[@version_key]) ->
        invalid_params("Missing or invalid _meta field: #{@version_key}")

      not is_map(meta[@caps_key]) ->
        invalid_params("Missing or invalid _meta field: #{@caps_key}")

      true ->
        :ok
    end
  end

  defp validate_header_body_match(conn, message, method, meta) do
    cond do
      header(conn, "mcp-protocol-version") != meta[@version_key] ->
        header_mismatch("MCP-Protocol-Version header does not match _meta protocolVersion")

      header(conn, "mcp-method") != method ->
        header_mismatch("Mcp-Method header does not match request method")

      method == "tools/call" and
          decode_header_value(header(conn, "mcp-name")) != get_in(message, ["params", "name"]) ->
        header_mismatch("Mcp-Name header does not match params.name")

      true ->
        :ok
    end
  end

  defp validate_version(meta) do
    version = meta[@version_key]

    if version in @supported_versions do
      :ok
    else
      {:error, 400, -32_022, "Unsupported protocol version",
       %{supported: @supported_versions, requested: version}}
    end
  end

  # No current method requires a client capability (roots/sampling/elicitation),
  # so this always passes today; it is the hook for capability-dependent methods.
  defp validate_capabilities(method, meta) do
    declared = meta[@caps_key] || %{}

    case Enum.reject(required_capabilities(method), &Map.has_key?(declared, &1)) do
      [] ->
        :ok

      missing ->
        {:error, 400, -32_021, "Missing required client capability",
         %{requiredCapabilities: missing}}
    end
  end

  defp required_capabilities(_method), do: []

  ## JSON-RPC dispatch

  defp dispatch(_conn, id, "server/discover", _message) do
    {200, success_response(id, discover_result())}
  end

  defp dispatch(_conn, id, "ping", _message) do
    {200, success_response(id, %{})}
  end

  defp dispatch(_conn, id, "tools/list", _message) do
    {200, success_response(id, %{tools: @tools})}
  end

  defp dispatch(conn, id, "tools/call", message) do
    params = message["params"] || %{}
    name = params["name"]
    arguments = params["arguments"] || %{}

    result =
      case call_tool(conn, name, arguments) do
        {:ok, value} -> %{content: [text_content(value)], isError: false}
        {:error, error_message} -> %{content: [text_content(error_message)], isError: true}
      end

    {200, success_response(id, result)}
  end

  defp dispatch(_conn, id, method, _message) do
    {404, error_response(id, -32_601, "Method not found: #{method}")}
  end

  defp discover_result() do
    %{
      supportedVersions: @supported_versions,
      capabilities: %{tools: %{}},
      instructions:
        "Plausible Analytics MCP server. Use list_sites to discover accessible sites, then query_stats to query analytics via the Stats API v2."
    }
  end

  ## Tools

  defp call_tool(conn, "list_sites", _arguments) do
    with :ok <- require_scope(conn, "sites:read:*") do
      user = conn.assigns.current_user
      team = conn.assigns.current_team

      sites =
        Plausible.Sites.for_user_query(user, team)
        |> Repo.all()
        |> Enum.map(&%{domain: &1.domain, timezone: &1.timezone})

      {:ok, %{sites: sites}}
    end
  end

  defp call_tool(conn, "query_stats", arguments) do
    with :ok <- require_scope(conn, "stats:read:*"),
         {:ok, site_id} <- fetch_string(arguments, "site_id"),
         {:ok, site} <- find_site(site_id),
         :ok <- verify_site_access(conn, site) do
      site = Repo.preload(site, :owners)
      params = Map.put(arguments, "site_id", site.domain)

      case Query.parse_and_build(site, params) do
        {:ok, query} ->
          {:ok, Plausible.Stats.query(site, query)}

        {:error, %QueryError{message: message}} ->
          {:error, message}
      end
    end
  end

  defp call_tool(_conn, name, _arguments) do
    {:error, "Unknown tool: #{name}"}
  end

  ## Authorization helpers

  defp require_scope(conn, required) do
    scopes = conn.assigns[:oauth_scopes] || []

    granted? =
      Enum.any?(scopes, fn scope ->
        String.starts_with?(required, String.trim_trailing(scope, "*"))
      end)

    if granted? do
      :ok
    else
      {:error, "The access token does not grant the required scope: #{required}"}
    end
  end

  defp find_site(site_id) do
    query =
      from s in Plausible.Site,
        where: s.domain == ^site_id or s.domain_changed_from == ^site_id

    case Repo.one(query) do
      %Plausible.Site{} = site -> {:ok, site}
      nil -> {:error, "Site not found or not accessible: #{site_id}"}
    end
  end

  defp verify_site_access(conn, site) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team
    site_team = Repo.preload(site, :team).team

    cond do
      Plausible.Auth.super_admin?(user.id) ->
        :ok

      team && team.id != site.team_id ->
        {:error, "The access token is not authorized for this site's team."}

      Plausible.Teams.locked?(site_team) ->
        {:error, "This site is locked due to a missing active subscription."}

      Plausible.Billing.Feature.StatsAPI.check_availability(site_team) != :ok ->
        {:error, "The team that owns this site does not have access to the Stats API."}

      Plausible.Teams.Memberships.site_member?(site, user) ->
        :ok

      true ->
        {:error, "You do not have access to this site."}
    end
  end

  ## JSON-RPC + HTTP helpers

  # Every successful result carries `resultType: "complete"` and identifies the
  # server via `_meta`, so the client needs no prior connection state.
  defp success_response(id, result) do
    result =
      result
      |> Map.put(:resultType, "complete")
      |> Map.update(:_meta, server_meta(), &Map.merge(server_meta(), &1))

    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp server_meta() do
    %{@server_info_key => %{name: @server_name, version: app_version()}}
  end

  defp error_response(id, code, message, data \\ nil) do
    error = %{code: code, message: message}
    error = if data, do: Map.put(error, :data, data), else: error
    %{jsonrpc: "2.0", id: id, error: error}
  end

  defp header_mismatch(message), do: {:error, 400, -32_020, message, nil}
  defp invalid_params(message), do: {:error, 400, -32_602, message, nil}

  defp text_content(value) when is_binary(value) do
    %{type: "text", text: value}
  end

  defp text_content(value) do
    %{type: "text", text: Jason.encode!(value)}
  end

  defp fetch_string(map, key) do
    case map[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing required argument: #{key}"}
    end
  end

  defp meta(message), do: get_in(message, ["params", "_meta"]) || %{}

  defp header(conn, name), do: conn |> get_req_header(name) |> List.first()

  defp name_header("tools/call"), do: ["mcp-name"]
  defp name_header(_method), do: []

  # `Mcp-Name` (and `Mcp-Param-*`) values may be carried as `=?base64?<b64>?=`
  # when they are not header-safe; decode before comparing against the body.
  defp decode_header_value("=?base64?" <> rest = value) do
    case String.split(rest, "?=", parts: 2) do
      [encoded, ""] ->
        case Base.decode64(encoded) do
          {:ok, decoded} -> decoded
          :error -> value
        end

      _ ->
        value
    end
  end

  defp decode_header_value(value), do: value

  defp send_json(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp app_version() do
    to_string(Application.spec(:plausible, :vsn) || "0.0.0")
  end
end
