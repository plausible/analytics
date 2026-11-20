defmodule PlausibleWeb.MCP.Span do
  @moduledoc """
  A span around one MCP request, so its tool call and queries group together
  under the HTTP span. Attribute names follow the
  [MCP semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/mcp.md).
  """

  require OpenTelemetry.Tracer, as: Tracer

  @known_methods ["server/discover", "tools/list", "tools/call"]

  @version_key "io.modelcontextprotocol/protocolVersion"
  @client_info_key "io.modelcontextprotocol/clientInfo"

  # The conventions do not count these as errors: the server could not serve
  # the request, but nothing failed.
  @non_error_codes [-32_700, -32_600, -32_601, -32_602]

  @doc """
  Runs `fun` in the span and records the outcome from the JSON-RPC response it
  sends, read from `conn.private[:mcp_response]`.
  """
  @spec with_span(Plug.Conn.t(), map(), [String.t()], (-> Plug.Conn.t())) :: Plug.Conn.t()
  def with_span(conn, message, tool_names, fun) do
    Tracer.with_span name(message, tool_names), %{
      attributes: request_attributes(message)
    } do
      if grant = conn.assigns[:oauth_grant] do
        Plausible.OpenTelemetry.add_oauth_grant_attributes(grant)
      end

      conn = fun.()

      {attributes, status} = outcome(conn.private[:mcp_response])
      Tracer.set_attributes(attributes)
      if status, do: Tracer.set_status(status)

      conn
    end
  end

  # Method and tool names are client-supplied, so only known ones make it into
  # the span name.
  defp name(%{"method" => "tools/call"} = message, tool_names) do
    tool = params(message)["name"]
    if tool in tool_names, do: "tools/call " <> tool, else: "tools/call"
  end

  defp name(%{"method" => method}, _tool_names) when method in @known_methods, do: method
  defp name(_message, _tool_names), do: "_OTHER"

  defp request_attributes(%{"method" => method} = message) do
    params = params(message)
    meta = map_at(params, "_meta")
    client_info = map_at(meta, @client_info_key)

    tool_attributes =
      if method == "tools/call" do
        [{"gen_ai.operation.name", "execute_tool"}, {"gen_ai.tool.name", params["name"]}]
      else
        []
      end

    [
      {"mcp.method.name", method},
      {"jsonrpc.request.id", id_string(message["id"])},
      {"mcp.protocol.version", meta[@version_key]},
      {"plausible.mcp.client.name", client_info["name"]},
      {"plausible.mcp.client.version", client_info["version"]}
      | tool_attributes
    ]
    |> Enum.filter(fn {_key, value} -> is_binary(value) end)
  end

  defp outcome(%{error: %{code: code}}) when code in @non_error_codes do
    {[{"rpc.status_code", Integer.to_string(code)}], nil}
  end

  defp outcome(%{error: %{code: code, message: message}}) do
    code = Integer.to_string(code)
    {[{"rpc.status_code", code}, {"error.type", code}], OpenTelemetry.status(:error, message)}
  end

  # A tool error is a successful JSON-RPC response
  defp outcome(%{result: %{isError: true, content: [%{text: text} | _]}}) do
    {[{"error.type", "tool_error"}], OpenTelemetry.status(:error, text)}
  end

  defp outcome(_response), do: {[], nil}

  defp params(message), do: map_at(message, "params")

  # Client-supplied values need not be objects
  defp map_at(map, key) do
    case map[key] do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp id_string(id) when is_binary(id), do: id
  defp id_string(id) when is_integer(id), do: Integer.to_string(id)
  defp id_string(_id), do: nil
end
