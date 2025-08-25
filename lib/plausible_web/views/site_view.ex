defmodule PlausibleWeb.SiteView do
  use PlausibleWeb, :view
  use Plausible

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def shared_link_dest(site, link) do
    Plausible.Sites.shared_link_url(site, link)
  end

  def with_indefinite_article(word) do
    if String.starts_with?(word, ["a", "e", "i", "o", "u"]) do
      "an " <> word
    else
      "a " <> word
    end
  end

  def site_role(%{role: :viewer}) do
    "Guest Viewer"
  end

  def site_role(%{role: :editor}) do
    "Guest Editor"
  end

  def site_role(%{role: role}) do
    role |> to_string() |> String.capitalize()
  end
end
