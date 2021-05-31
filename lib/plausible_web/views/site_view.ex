defmodule PlausibleWeb.SiteView do
  use PlausibleWeb, :view
  import Phoenix.Pagination.HTML

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def base_domain() do
    PlausibleWeb.Endpoint.host()
  end

  def goal_name(%Plausible.Goal{page_path: page_path}) when is_binary(page_path) do
    "Visit " <> page_path
  end

  def goal_name(%Plausible.Goal{event_name: name}) when is_binary(name) do
    name
  end

  def shared_link_dest(site, link) do
    Plausible.Sites.shared_link_url(site, link)
  end

  def gravatar(email, opts) do
    hash =
      email
      |> String.trim()
      |> String.downcase()
      |> :erlang.md5()
      |> Base.encode16(case: :lower)

    img = "https://www.gravatar.com/avatar/#{hash}?s=150&d=identicon"
    img_tag(img, opts)
  end

  def snippet(site) do
    tracker =
      if site.custom_domain do
        "https://" <> site.custom_domain.domain <> "/js/index.js"
      else
        "#{plausible_url()}/js/plausible.js"
      end

    """
    <script defer data-domain="#{site.domain}" src="#{tracker}"></script>
    """
  end
end
