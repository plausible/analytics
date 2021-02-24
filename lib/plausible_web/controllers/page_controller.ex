defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug PlausibleWeb.AutoAuthPlug
       when action == :index

  def index(conn, _params) do
    if conn.assigns[:current_user] do
      user = conn.assigns[:current_user] |> Repo.preload(:sites)
      render(conn, "sites.html", sites: user.sites)
    else
      render(conn, "index.html")
    end
  end

  def licenses_table(conn, _) do
    render(conn, "licenses.html")
  end
end
