defmodule PlausibleWeb.MCP.MCPController do
  @moduledoc """
  Model Context Protocol (MCP) endpoint over Streamable HTTP, implementing the
  stateless `2026-07-28` revision of the protocol.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth.ProtectedResources
  alias Plausible.Stats.{Query, QueryError}
  alias Plausible.Teams.Membership
  alias PlausibleWeb.Plugs.AuthorizeOAuthAPI

  require Logger

  @resource ProtectedResources.mcp()

  @supported_versions ["2026-07-28"]

  @public_methods ["server/discover"]

  plug :authorize when action == :handle

  defp authorize(conn, _opts) do
    case message(conn.body_params) do
      {:ok, _message, method, _id} when method not in @public_methods ->
        AuthorizeOAuthAPI.call(conn, resource: @resource)

      _public_or_unroutable ->
        conn
    end
  end

  @cache_ttl_ms :timer.minutes(5)
  @cache_scope "public"

  @version_key "io.modelcontextprotocol/protocolVersion"
  @capabilities_key "io.modelcontextprotocol/clientCapabilities"
  @server_info_key "io.modelcontextprotocol/serverInfo"

  # Config for each tool. Public fields are served in `tools/list` call.
  @public_fields [:name, :description, :inputSchema]
  @tool_specs [
    %{
      name: "list_sites",
      scope: ProtectedResources.scope!(@resource, Scopes.sites_read()),
      roles: Membership.roles!([:owner, :admin, :editor, :billing, :viewer]),
      can_be_used_with_locked_team?: true,
      description:
        "List the sites (websites) the authorized team has access to. Returns each site's domain and timezone.",
      inputSchema: %{type: "object", properties: %{}, additionalProperties: false}
    },
    %{
      name: "query_stats",
      scope: ProtectedResources.scope!(@resource, Scopes.stats_read()),
      roles: Membership.roles!([:owner, :admin, :editor, :billing, :viewer]),
      description:
        "Query a site's analytics. Accepts the same query as the #{Plausible.product_name()} Stats API v2 " <>
          "(POST /api/v2/query): `site_id` is a domain from list_sites. Returns the results, " <>
          "along with the query as it was interpreted.",
      inputSchema: Plausible.Stats.JSONSchema.raw_schema()
    }
  ]

  @tools Enum.map(@tool_specs, &Map.take(&1, @public_fields))
  @tools_by_name Map.new(@tool_specs, &{&1.name, &1})

  @doc """
  Answers a single JSON-RPC request (https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#sending-messages).
  """
  def handle(conn, _params) do
    case message(conn.body_params) do
      {:ok, message, method, id} ->
        handle_request(conn, message, method, id)

      :error ->
        send_json(conn, 400, error_response(nil, -32_600, "Invalid Request"))
    end
  end

  @doc """
  Rejects `GET` and `DELETE`, which earlier MCP versions used for session management.
  This implementation is not backwards-compatible (https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#earlier-streamable-http-revisions).
  """
  def not_supported(conn, _params) do
    conn
    |> put_status(405)
    |> json(%{error: "method_not_allowed", error_description: "Use POST for MCP."})
  end

  defp handle_request(conn, message, method, id) do
    meta = meta(message)

    with :ok <- validate_headers_present(conn, method),
         :ok <- validate_meta_fields(meta),
         :ok <- validate_header_body_match(conn, message, method, meta),
         :ok <- validate_version(meta) do
      case dispatch(conn, id, method, message) do
        {status, body} -> send_json(conn, status, body)
        {status, body, headers} -> conn |> merge_resp_headers(headers) |> send_json(status, body)
      end
    else
      {:error, status, code, error_message, data} ->
        send_json(conn, status, error_response(id, code, error_message, data))
    end
  end

  defp message(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = message)
       when is_binary(method),
       do: {:ok, message, method, id}

  defp message(_body_params), do: :error

  @always_expected_headers ["mcp-protocol-version", "mcp-method"]
  defp validate_headers_present(conn, method) do
    expected_headers =
      if(expect_name_header?(method),
        do: ["mcp-name"],
        else: []
      )

    expected_headers = expected_headers ++ @always_expected_headers

    case Enum.filter(expected_headers, fn header -> conn |> get_header(header) |> is_nil() end) do
      [] ->
        :ok

      [first_missing_header | _] ->
        header_mismatch("Missing required header: #{first_missing_header}")
    end
  end

  defp validate_meta_fields(meta) do
    cond do
      not is_binary(meta[@version_key]) ->
        invalid_params("Missing or invalid _meta field: #{@version_key}")

      not is_map(meta[@capabilities_key]) ->
        invalid_params("Missing or invalid _meta field: #{@capabilities_key}")

      true ->
        :ok
    end
  end

  # The body is the source of truth. Headers must match the body.
  defp validate_header_body_match(conn, message, method, meta) do
    cond do
      get_header(conn, "mcp-protocol-version") != meta[@version_key] ->
        header_mismatch("Header mcp-protocol-version does not match _meta protocolVersion")

      get_header(conn, "mcp-method") != method ->
        header_mismatch("Header mcp-method does not match request method")

      expect_name_header?(method) and
          decode_header_value(get_header(conn, "mcp-name")) != params(message)["name"] ->
        header_mismatch("Header mcp-name does not match params.name")

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

  defp dispatch(_conn, id, "server/discover", _message) do
    {200, success_response(id, cacheable(discover_result()))}
  end

  defp dispatch(_conn, id, "tools/list", _message) do
    {200, success_response(id, cacheable(%{tools: @tools}))}
  end

  defp dispatch(conn, id, "tools/call", message) do
    params = params(message)
    name = params["name"]

    case Map.fetch(@tools_by_name, name) do
      {:ok, spec} ->
        case call_tool(conn, spec, params) do
          {:ok, value} ->
            {200, success_response(id, %{content: [text_content(value)], isError: false})}

          {:error, :insufficient_scope, scope} ->
            {403, %{error: "insufficient_scope"},
             [
               {"www-authenticate", AuthorizeOAuthAPI.challenge(@resource, scope)}
             ]}

          # A role is not something re-authorizing can change, so this stays a
          # tool error: the user has to ask an admin, and the model should say so.
          {:error, message} ->
            {200, success_response(id, %{content: [text_content(message)], isError: true})}
        end

      :error ->
        {400, error_response(id, -32_602, "Unknown tool")}
    end
  end

  defp dispatch(_conn, id, _method, _message) do
    {404, error_response(id, -32_601, "Method not found")}
  end

  defp cacheable(result) do
    Map.merge(result, %{ttlMs: @cache_ttl_ms, cacheScope: @cache_scope})
  end

  defp discover_result do
    %{
      supportedVersions: @supported_versions,
      capabilities: %{tools: %{}},
      instructions:
        "#{Plausible.product_name()} MCP server. Use list_sites to discover the sites the authorized team can access, then query_stats to query their analytics."
    }
  end

  defp call_tool(conn, spec, tool_args) do
    with :ok <- require_scope(conn, spec.scope),
         :ok <- require_role(conn, spec.roles),
         :ok <- maybe_require_unlocked_team(conn, spec) do
      run_tool(conn, spec.name, tool_args)
    end
  end

  defp run_tool(conn, "list_sites", _tool_args) do
    sites =
      conn.assigns.current_user
      |> Plausible.Sites.list_for_team_member(conn.assigns.current_team)
      |> Enum.map(&Map.take(&1, [:domain, :timezone]))

    {:ok, %{sites: sites}}
  end

  defp run_tool(conn, "query_stats", tool_args) do
    query_params = tool_args["arguments"]

    with :ok <- validate_arguments(query_params),
         {:ok, site} <- find_site(conn, query_params["site_id"]),
         {:ok, query} <-
           Query.parse_and_build(site, query_params,
             debug_metadata: debug_metadata(assign(conn, :site, site)),
             now: conn.private[:now]
           ) do
      # `QueryResult` only implements `Jason.Encoder`, so it is encoded here
      # rather than by `text_content/1`.
      {:ok, site |> Plausible.Stats.query(query) |> Jason.encode!()}
    else
      {:error, %QueryError{message: message}} -> {:error, message}
      {:error, message} -> {:error, message}
    end
  end

  defp validate_arguments(arguments) when is_map(arguments), do: :ok
  defp validate_arguments(_arguments), do: {:error, "Tool arguments must be an object"}

  # Looks the site up within the grant's team only, the same set list_sites returns.
  defp find_site(conn, domain) when is_binary(domain) do
    case Plausible.Sites.get_for_team_member(
           conn.assigns.current_user,
           conn.assigns.current_team,
           domain
         ) do
      nil ->
        {:error, "Site #{domain} not found. Use list_sites to see the sites you can query."}

      site ->
        {:ok, Repo.preload(site, [:owners, :completed_imports])}
    end
  end

  defp find_site(_conn, _domain),
    do: {:error, "Missing site_id. Use list_sites to see the sites you can query."}

  defp require_scope(conn, scope) do
    if scope in (conn.assigns[:oauth_scopes] || []) do
      :ok
    else
      {:error, :insufficient_scope, scope}
    end
  end

  defp require_role(conn, roles) do
    role = conn.assigns[:current_team_role]

    if role in roles do
      :ok
    else
      {:error,
       "Your role in this team (#{role}) does not permit this action. It requires one of: " <>
         Enum.map_join(roles, ", ", &to_string/1)}
    end
  end

  # Like a role, a lock is not something re-authorizing can change,
  # so it is a tool error naming what the team has to do.
  defp maybe_require_unlocked_team(conn, spec) do
    if Map.get(spec, :can_be_used_with_locked_team?, false) or
         not Plausible.Teams.locked?(conn.assigns.current_team) do
      :ok
    else
      {:error,
       "This team is locked due to missing active subscription. In order to use this tool, the team owner should subscribe to a suitable plan."}
    end
  end

  defp success_response(id, result) do
    result = Map.merge(result, %{resultType: "complete", _meta: server_meta()})

    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp server_meta do
    %{@server_info_key => %{name: Plausible.product_name(), version: app_version()}}
  end

  defp error_response(id, code, message, data \\ nil) do
    error = %{code: code, message: message}
    error = if data, do: Map.put(error, :data, data), else: error
    %{jsonrpc: "2.0", id: id, error: error}
  end

  defp header_mismatch(message), do: {:error, 400, -32_020, message, nil}
  defp invalid_params(message), do: {:error, 400, -32_602, message, nil}

  defp text_content(value) when is_binary(value), do: %{type: "text", text: value}
  defp text_content(value), do: %{type: "text", text: JSON.encode!(value)}

  # `params` and `_meta` are client-supplied and need not be objects. `get_in/2`
  # raises on a scalar or a list, so neither is ever indexed into directly.
  defp params(%{"params" => params}) when is_map(params), do: params
  defp params(_message), do: %{}

  defp meta(message) do
    case params(message) do
      %{"_meta" => meta} when is_map(meta) -> meta
      _ -> %{}
    end
  end

  defp get_header(conn, name), do: conn |> get_req_header(name) |> List.first()

  defp expect_name_header?("tools/call" = _method), do: true
  defp expect_name_header?(_method), do: false

  # `Mcp-Name` arrives as `=?base64?<encoded>?=` when the value isn't header-safe,
  # so decode it before comparing against the body.
  defp decode_header_value("=?base64?" <> rest = value) do
    with [encoded, ""] <- String.split(rest, "?=", parts: 2),
         {:ok, decoded} <- Base.decode64(encoded) do
      decoded
    else
      _ -> value
    end
  end

  defp decode_header_value(value), do: value

  defp send_json(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp app_version do
    runtime_version() || to_string(Application.spec(:plausible, :vsn) || "0.0.0")
  end

  defp runtime_version do
    :plausible
    |> Application.get_env(:runtime_metadata, [])
    |> Keyword.get(:version)
  end
end
