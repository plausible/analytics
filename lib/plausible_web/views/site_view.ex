defmodule PlausibleWeb.SiteView do
  use PlausibleWeb, :view
  use Plausible

  alias Plausible.Imported.SiteImport

  require Plausible.Imported.SiteImport

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def shared_link_dest(site, link) do
    Plausible.Sites.shared_link_url(site, link)
  end

  def render_snippet(site) do
    tracker = "#{plausible_url()}/js/script.js"

    """
    <script defer data-domain="#{site.domain}" src="#{tracker}"></script>
    """
  end

  def with_indefinite_article(word) do
    if String.starts_with?(word, ["a", "e", "i", "o", "u"]) do
      "an " <> word
    else
      "a " <> word
    end
  end
end
