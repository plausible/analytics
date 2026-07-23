defmodule PlausibleWeb.MCP.MCPController do
  @moduledoc """
  Model Context Protocol (MCP) endpoint over Streamable HTTP.

  Implements the minimal JSON-RPC 2.0 surface required by a remote connector:
  `initialize`, `ping`, `tools/list`, `tools/call`, and `notifications/*`
  (acknowledged with `202`). Responses are returned directly as
  `application/json`; the optional SSE transport is not implemented (`GET /mcp`
  returns `405`).

  Two tools are exposed:

    * `list_sites` - the sites of the token's bound team (scope `sites:read:*`).
    * `query_stats` - wraps the Stats API `POST /api/v2/query` (scope
      `stats:read:*`).

  Authentication, rate limiting and `current_user`/`current_team` assignment are
  handled upstream by `PlausibleWeb.Plugs.AuthorizeOAuthAPI`.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Stats.{Query, QueryError}

  @protocol_version "2025-06-18"
  @server_name "Plausible Analytics"

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
      %{"_json" => messages} when is_list(messages) ->
        respond(conn, messages, Enum.map(messages, &dispatch(conn, &1)))

      %{"jsonrpc" => _} = message ->
        respond(conn, [message], [dispatch(conn, message)])

      _ ->
        send_json(conn, 400, error_response(nil, -32_600, "Invalid Request"))
    end
  end

  def not_supported(conn, _params) do
    send_json(conn, 405, error_response(nil, -32_000, "Method not allowed. Use POST for MCP."))
  end

  # A batch/single request may contain `initialize`, in which case we assign a
  # session id via the `Mcp-Session-Id` response header. Requests without a
  # response (only notifications) are acknowledged with `202`.
  defp respond(conn, messages, responses) do
    conn = maybe_put_session_id(conn, messages)
    responses = Enum.reject(responses, &is_nil/1)

    case {conn.body_params, responses} do
      {_, []} -> send_resp(conn, 202, "")
      {%{"_json" => _}, _} -> send_json(conn, 200, responses)
      {_, [response]} -> send_json(conn, 200, response)
      {_, _} -> send_json(conn, 200, responses)
    end
  end

  defp maybe_put_session_id(conn, messages) do
    if Enum.any?(messages, &(is_map(&1) and &1["method"] == "initialize")) do
      put_resp_header(conn, "mcp-session-id", generate_session_id())
    else
      conn
    end
  end

  ## JSON-RPC dispatch

  defp dispatch(_conn, %{"method" => "notifications/" <> _}), do: nil

  defp dispatch(_conn, %{"method" => "initialize", "id" => id} = message) do
    requested = get_in(message, ["params", "protocolVersion"])
    version = if is_binary(requested), do: requested, else: @protocol_version

    result = %{
      protocolVersion: version,
      capabilities: %{tools: %{}},
      serverInfo: %{name: @server_name, version: app_version()}
    }

    success_response(id, result)
  end

  defp dispatch(_conn, %{"method" => "ping", "id" => id}) do
    success_response(id, %{})
  end

  defp dispatch(_conn, %{"method" => "tools/list", "id" => id}) do
    success_response(id, %{tools: @tools})
  end

  defp dispatch(conn, %{"method" => "tools/call", "id" => id, "params" => params}) do
    name = params["name"]
    arguments = params["arguments"] || %{}

    case call_tool(conn, name, arguments) do
      {:ok, result} ->
        success_response(id, %{content: [text_content(result)], isError: false})

      {:error, message} ->
        success_response(id, %{content: [text_content(message)], isError: true})
    end
  end

  defp dispatch(_conn, %{"id" => id, "method" => method}) do
    error_response(id, -32_601, "Method not found: #{method}")
  end

  defp dispatch(_conn, _message), do: nil

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

  defp success_response(id, result) do
    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp error_response(id, code, message) do
    %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
  end

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

  defp send_json(conn, status, body) do
    conn
    |> put_status(status)
    |> json(body)
  end

  defp generate_session_id() do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp app_version() do
    to_string(Application.spec(:plausible, :vsn) || "0.0.0")
  end
end
