defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  @doc """
  The root path is never accessible in Plausible.Cloud because it is handled by the upstream reverse proxy.

  This controller action is only ever triggered in self-hosted Plausible. It redirects the user to /login where `PlausibleWeb.RequireLoggedOutPlug` plug kicks in. If they are already logged in, they are redirected to /sites, otherwise they'll see the /login page.
  """
  def index(conn, _params) do
    conn
    |> put_session(:login_dest, conn.request_path)
    |> redirect(to: "/login")
  end
end
