defmodule PlausibleWeb.RequireLoggedOutPlug do
  def init(options) do
    options
  end

  def call(conn, _opts) do
    cond do
      conn.assigns[:current_user] ->
        conn
        |> Phoenix.Controller.redirect(to: "/")
        |> Plug.Conn.halt
      :else ->
        conn
    end
  end
end
