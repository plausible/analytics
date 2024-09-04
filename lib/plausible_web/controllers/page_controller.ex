defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug PlausibleWeb.RequireLoggedOutPlug

  @doc """
  The root path is never accessible in Plausible.Cloud because it is handled by the upstream reverse proxy.

  This controller action is only ever triggered in self-hosted Plausible.
  """
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
