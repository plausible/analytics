defmodule PlausibleWeb.MCP.Span do
  @moduledoc """
  The OpenTelemetry server span for one MCP request, following the
  [MCP semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/mcp.md).

  The conventions prefer a trace context sent in `params._meta` as the parent.
  The span is a child of the HTTP server span instead, so every request stays
  in a trace of our own, which tail sampling relies on.
  """

  require OpenTelemetry.Tracer, as: Tracer

  @known_methods ["server/discover", "tools/list", "tools/call"]

  @version_key "io.modelcontextprotocol/protocolVersion"
  @client_info_key "io.modelcontextprotocol/clientInfo"

  # The conventions do not count these as errors: the server could not serve
  # the request, but nothing failed.
  @non_error_codes [-32_700, -32_600, -32_601, -32_602]

  @doc """
  Runs `fun` in the span and records the outcome from the conn it returns.

  The outcome is the JSON-RPC response in `conn.private[:mcp_response]`, or the
  HTTP status when there is none, e.g. when authorization halted the conn.
  """
  @spec with_span(Plug.Conn.t(), map(), [String.t()], (Plug.Conn.t() -> Plug.Conn.t())) ::
          Plug.Conn.t()
  def with_span(conn, message, tool_names, fun) do
    Tracer.with_span name(message, tool_names), %{
      kind: :server,
      attributes: request_attributes(message)
    } do
      try do
        conn = fun.(conn)

        {attributes, status} = outcome(conn.status, conn.private[:mcp_response])
        Tracer.set_attributes(attributes)
        if status, do: Tracer.set_status(status)

        conn
      rescue
        # `with_span` only ends the span, so a crash would look like a success
        exception ->
          Tracer.record_exception(exception, __STACKTRACE__)
          Tracer.set_attributes([{"error.type", inspect(exception.__struct__)}])
          Tracer.set_status(OpenTelemetry.status(:error, Exception.message(exception)))
          reraise exception, __STACKTRACE__
      end
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

  defp outcome(_http_status, %{error: %{code: code}}) when code in @non_error_codes do
    {[{"rpc.status_code", Integer.to_string(code)}], nil}
  end

  defp outcome(_http_status, %{error: %{code: code, message: message}}) do
    code = Integer.to_string(code)
    {[{"rpc.status_code", code}, {"error.type", code}], OpenTelemetry.status(:error, message)}
  end

  # A tool error is a successful JSON-RPC response
  defp outcome(_http_status, %{result: %{isError: true, content: [%{text: text} | _]}}) do
    {[{"error.type", "tool_error"}], OpenTelemetry.status(:error, text)}
  end

  # Not errors, so unauthenticated traffic doesn't bypass trace sampling
  defp outcome(http_status, _body) when http_status in [401, 403, 429] do
    {[{"error.type", Integer.to_string(http_status)}], nil}
  end

  defp outcome(http_status, _body) when is_integer(http_status) and http_status >= 400 do
    {[{"error.type", Integer.to_string(http_status)}], OpenTelemetry.status(:error)}
  end

  defp outcome(_http_status, _body), do: {[], nil}

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
