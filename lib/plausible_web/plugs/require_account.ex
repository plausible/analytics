defmodule PlausibleWeb.RequireAccountPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        Plug.Conn.put_session(conn, :login_dest, conn.request_path)
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt

      _email ->
        conn
    end
  end
end
