defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def index(conn, _params) do
    conn
    |> put_session(:login_dest, conn.request_path)
    |> redirect(to: "/login")
  end
end
