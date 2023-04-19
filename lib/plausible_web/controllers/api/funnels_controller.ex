defmodule PlausibleWeb.Api.FunnelsController do
  use PlausibleWeb, :controller

  alias Plausible.Funnels

  def show(conn, %{"id" => funnel_id}) do
    site_id = conn.assigns.site.id
    {funnel_id, ""} = Integer.parse(funnel_id)
    funnel = Funnels.evaluate(:nop, funnel_id, site_id)

    json(conn, funnel)
  end
end
