defmodule PlausibleWeb.AuthorizeApiStatsPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    site = Repo.get_by(Plausible.Site, domain: conn.params["site_id"])

    if !site do
      not_found(conn)
    else
      can_access = true

      if !can_access do
        not_found(conn)
        PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
      else
        assign(conn, :site, site)
      end
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> Phoenix.Controller.json(%{error: "Not found"})
  end
end
