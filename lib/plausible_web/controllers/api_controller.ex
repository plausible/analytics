defmodule PlausibleWeb.ApiController do
  use PlausibleWeb, :controller
  require Logger
  use Plausible.Repo

  def domain_status(conn, %{"domain" => domain}) do
    has_pageviews = Repo.exists?(
      from p in Plausible.Pageview,
      where: p.hostname == ^domain
    )

    if has_pageviews do
      json(conn, "READY")
    else
      json(conn, "WAITING")
    end
  end
end
