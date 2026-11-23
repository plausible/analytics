defmodule PlausibleWeb.RawBodyReader do
  @moduledoc """
  `Plug.Parsers` body reader that keeps the raw request body in
  `conn.private[:raw_body]` for webhooks verified over the exact bytes sent.

  Other routes are not affected, so regular requests (like event ingestion)
  don't pay for a second copy of the body.
  """

  use PlausibleWeb.VerifiedRoutes

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      {:ok, body, cache(conn, body)}
    end
  end

  def raw_body(conn), do: conn.private[:raw_body] || ""

  defp cache(conn, body) do
    if conn.request_path == ~p"/api/paddle-billing/webhook" do
      Plug.Conn.put_private(conn, :raw_body, body)
    else
      conn
    end
  end
end
