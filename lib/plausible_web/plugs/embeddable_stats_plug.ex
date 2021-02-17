defmodule PlausibleWeb.EmbeddableStatsPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(%{assigns: %{site: site}} = conn, _opts) do
    if !site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      if !site.embeddable || !get_session(conn, "embed_mode") do
        assign(conn, :site, site)
      else
        conn
        |> put_resp_header("x-frame-options", "allow-from " <> site.domain)
        |> put_resp_header("content-security-policy", "frame-ancestors " <> site.domain)
        |> assign(:site, site)
      end
    end
  end
end
