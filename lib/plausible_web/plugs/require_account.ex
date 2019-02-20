defmodule PlausibleWeb.RequireAccountPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        Phoenix.Controller.redirect(conn, to: "/login")
        |> halt
      _email ->
        conn
    end
  end
end
