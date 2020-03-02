defmodule PlausibleWeb.SiteView do
  use PlausibleWeb, :view

  def goal_name(%Plausible.Goal{page_path: page_path}) when is_binary(page_path)  do
    "Visit " <> page_path
  end

  def goal_name(%Plausible.Goal{event_name: name}) when is_binary(name) do
    name
  end

  def shared_link_dest(link) do
    PlausibleWeb.Endpoint.url() <> "/share/" <> link.slug
  end

  def snippet(site) do
    tracker = if site.custom_domain do
      "https://" <> site.custom_domain.domain <> "/js/index.js"
    else
      "https://plausible.io/js/plausible.js"
    end

    """
    <script async defer data-domain="#{site.domain}" src="#{tracker}"></script>
    """
  end
end
