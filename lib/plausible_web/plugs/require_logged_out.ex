defmodule PlausibleWeb.RequireLoggedOutPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    cond do
      conn.assigns[:current_user] ->
        conn
        |> put_resp_cookie("logged_in", "true")
        |> Phoenix.Controller.redirect(to: "/")
        |> halt
      :else ->
        conn
    end
  end
end
