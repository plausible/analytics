defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def index(conn, _params) do
    # TODO 1.6.0 cut down on redirection
    #
    # To keep the same flow as with AutoAuthPlug before, right now the following happens:
    #   for a logged in user:
    #     / -> PageController -> /login -> AuthController -> RequireLoggedOutPlug -> /sites
    #   for a logged out user:
    #     / -> PageController -> /login -> AuthController.login_form
    #
    # Relevant PR: https://github.com/plausible/analytics/pull/2357

    conn
    |> put_session(:login_dest, conn.request_path)
    |> redirect(to: "/login")
  end
end
