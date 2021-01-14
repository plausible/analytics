defmodule PlausibleWeb.EmbeddableAuthSharedLinkPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    shared_link =
      Repo.get_by(Plausible.Site.SharedLink, slug: conn.params["slug"])
      |> Repo.preload(:site)

    if !shared_link || !shared_link.site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      if (!shared_link.site.embeddable) || (Enum.at(conn.path_info, 1) != "embed")  do
        assign(conn, :shared_link, shared_link)
      else
        conn
        |> put_resp_header("x-frame-options", "allow-from " <> shared_link.site.domain)
        |> put_resp_header("content-security-policy", "frame-ancestors " <> shared_link.site.domain)
        |> assign(:shared_link, shared_link)
      end
    end
  end
end
