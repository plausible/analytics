defmodule PlausibleWeb.Api.InternalController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats.Clickhouse, as: Stats

  def domain_status(conn, %{"domain" => domain}) do
    if Stats.has_pageviews?(%Plausible.Site{domain: domain}) do
      json(conn, "READY")
    else
      json(conn, "WAITING")
    end
  end
end
