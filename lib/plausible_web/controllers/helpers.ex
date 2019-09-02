defmodule PlausibleWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller

  def render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> put_view(PlausibleWeb.ErrorView)
    |> render("#{status}.html", layout: false, message: message)
  end

  def render_error(conn, status) do
    conn
    |> put_status(status)
    |> put_view(PlausibleWeb.ErrorView)
    |> render("#{status}.html", layout: false)
  end
end
