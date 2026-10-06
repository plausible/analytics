defmodule PlausibleWeb.MCP.MCPController do
  @moduledoc """
  Model Context Protocol (MCP) endpoint over Streamable HTTP, implementing the
  stateless `2026-07-28` revision of the protocol.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo

  import Ecto.Query, only: [select: 3]

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth.ProtectedResources
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

  defp message(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = message)
       when is_binary(method),
       do: {:ok, message, method, id}

  defp message(_body_params), do: :error

  @cache_ttl_ms :timer.minutes(5)
  @cache_scope "public"

  @version_key "io.modelcontextprotocol/protocolVersion"
  @caps_key "io.modelcontextprotocol/clientCapabilities"
  @server_info_key "io.modelcontextprotocol/serverInfo"

  # Every tool declares what scope is needed on the OAuth grant
  # and what role in the team is needed.
  @tool_specs [
    %{
      name: "list_sites",
      scope: ProtectedResources.scope!(@resource, Scopes.sites_read()),
      roles: Membership.roles!([:owner, :admin, :editor, :billing, :viewer]),
      description:
        "List the sites (websites) the authorized team has access to. Returns each site's domain and timezone.",
      inputSchema: %{type: "object", properties: %{}, additionalProperties: false}
    }
  ]

  @tools Enum.map(@tool_specs, &Map.drop(&1, [:scope, :roles]))
  @tools_by_name Map.new(@tool_specs, &{&1.name, &1})

  @doc """
  Answers a single JSON-RPC request (https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#sending-messages).
  """
  def handle(conn, _params) do
    case message(conn.body_params) do
      {:ok, message, method, id} ->
        handle_request(conn, message, method, id)

      :error ->
        log_rejection(conn, "body is not a single JSON-RPC request", body: conn.body_params)

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
        log_rejection(conn, error_message, jsonrpc_code: code, method: method, meta: meta)

        send_json(conn, status, error_response(id, code, error_message, data))
    end
  end

  defp log_rejection(conn, reason, details) do
    Logger.debug(fn ->
      headers =
        for name <- ~w(mcp-protocol-version mcp-method mcp-name mcp-session-id last-event-id),
            value = header(conn, name),
            do: "#{name}: #{value}"

      details =
        Enum.map(details, fn
          {key, value} when is_map(value) -> {key, value |> Map.keys() |> Enum.sort()}
          pair -> pair
        end)

      [
        "MCP request rejected: ",
        reason,
        "\n  details: ",
        inspect(details),
        "\n  mcp headers: ",
        if(headers == [], do: "(none sent)", else: Enum.join(headers, ", "))
      ]
    end)
  end

  defp validate_headers_present(conn, method) do
    expected_headers = ["mcp-protocol-version", "mcp-method"] ++ name_header(method)

    case Enum.find(expected_headers, fn header -> header(conn, header) == nil end) do
      nil -> :ok
      header -> header_mismatch("Missing required header: #{header}")
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

  # The body is the source of truth. Headers must match the body.
  defp validate_header_body_match(conn, message, method, meta) do
    cond do
      header(conn, "mcp-protocol-version") != meta[@version_key] ->
        header_mismatch("Mcp-Protocol-Version header does not match _meta protocolVersion")

      header(conn, "mcp-method") != method ->
        header_mismatch("Mcp-Method header does not match request method")

      method == "tools/call" and
          decode_header_value(header(conn, "mcp-name")) != params(message)["name"] ->
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
        case call_tool(conn, spec, arguments(params)) do
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

  defp arguments(%{"arguments" => arguments}) when is_map(arguments), do: arguments
  defp arguments(_params), do: %{}

  defp cacheable(result) do
    Map.merge(result, %{ttlMs: @cache_ttl_ms, cacheScope: @cache_scope})
  end

  defp discover_result do
    %{
      supportedVersions: @supported_versions,
      capabilities: %{tools: %{}},
      instructions:
        "#{Plausible.product_name()} MCP server. Use list_sites to discover the sites the authorized team can access."
    }
  end

  defp call_tool(conn, spec, arguments) do
    with :ok <- require_scope(conn, spec.scope),
         :ok <- require_role(conn, spec.roles) do
      run_tool(conn, spec.name, arguments)
    end
  end

  defp run_tool(conn, "list_sites", _arguments) do
    sites =
      conn.assigns.current_user
      |> Plausible.Sites.for_user_query(conn.assigns.current_team)
      |> select([site: s], %{domain: s.domain, timezone: s.timezone})
      |> Repo.all()

    {:ok, %{sites: sites}}
  end

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
  defp text_content(value), do: %{type: "text", text: Jason.encode!(value)}

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

  defp header(conn, name), do: conn |> get_req_header(name) |> List.first()

  defp name_header("tools/call"), do: ["mcp-name"]
  defp name_header(_method), do: []

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
