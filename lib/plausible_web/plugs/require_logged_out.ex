defmodule PlausibleWeb.RequireLoggedOutPlug do
  import Plug.Conn

  def init(opts \\ []) do
    opts
  end

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> Phoenix.Controller.redirect(to: "/sites")
      |> halt()
    else
      conn
    end
  end
end
