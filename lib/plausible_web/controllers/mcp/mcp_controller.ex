defmodule PlausibleWeb.MCP.MCPController do
  @moduledoc """
  Model Context Protocol (MCP) endpoint over Streamable HTTP, implementing the
  stateless `2026-07-28` revision of the protocol.
  """

  use PlausibleWeb, :controller

  @doc """
  Answers a single JSON-RPC request (https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#sending-messages).
  """
  def handle(conn, _params) do
    conn
    |> put_status(501)
    |> json(%{error: "not_implemented"})
  end

  @doc """
  Handles `GET` and `DELETE` verbs that earlier MCP versions used for session management by rejecting them.
  This implementation is not backwards-compatible (https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#earlier-streamable-http-revisions).
  """
  def not_supported(conn, _params) do
    conn
    |> put_status(405)
    |> json(%{error: "method_not_allowed", error_description: "Use POST for MCP."})
  end
end
