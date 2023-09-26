defmodule PlausibleWeb.Plugins.API.Errors do
  @moduledoc """
  Common responses for Plugins API
  """

  import Plug.Conn

  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", ~s[Basic realm="Plugins API Access"])
    |> error(:unauthorized, "Plugins API: unauthorized")
  end

  @spec error(Plug.Conn.t(), Plug.Conn.status(), String.t() | [String.t()]) :: Plug.Conn.t()
  def error(conn, status, message) when is_binary(message) do
    error(conn, status, [message])
  end

  def error(conn, status, messages) when is_list(messages) do
    response =
      Jason.encode!(%{
        errors: Enum.map(messages, &%{detail: &1})
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, response)
    |> halt()
  end
end
