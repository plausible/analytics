defmodule PlausibleWeb.Plugins.API.Views.SharedLink do
  @moduledoc """
  View for rendering Shared Links in the Plugins API
  """

  use PlausibleWeb, :plugins_api_view

  def render("index.json", %{
        pagination: %{entries: shared_links, metadata: metadata},
        authorized_site: site,
        conn: conn
      }) do
    %{
      shared_links:
        render_many(shared_links, __MODULE__, "shared_link.json",
          authorized_site: site,
          as: :shared_link
        ),
      meta:
        render_metadata_links(metadata, :plugins_api_shared_links_url, :index, conn.query_params)
    }
  end

  def render("shared_link.json", %{
        shared_link: shared_link,
        authorized_site: site
      }) do
    %{
      shared_link: %{
        id: shared_link.id,
        name: shared_link.name,
        password_protected: is_binary(shared_link.password_hash),
        href: Plausible.Sites.shared_link_url(site, shared_link)
      }
    }
  end
end
