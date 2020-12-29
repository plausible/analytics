defmodule PlausibleWeb.RequireLoggedOutPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    cond do
      conn.assigns[:current_user] ->
        conn
        |> put_resp_cookie("logged_in", "true",
          http_only: false,
          max_age: 60 * 60 * 24 * 365 * 5000
        )
        |> Phoenix.Controller.redirect(to: "/sites")
        |> halt

      :else ->
        conn
    end
  end
end
