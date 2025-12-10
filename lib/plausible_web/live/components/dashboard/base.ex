defmodule PlausibleWeb.Components.Dashboard.Base do
  @moduledoc """
  Common components for dasbhaord.
  """

  use PlausibleWeb, :component

  attr :href, :string, required: true
  attr :site, Plausible.Site, required: true
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def dashboard_link(assigns) do
    url = "/" <> assigns.site.domain <> assigns.href

    assigns = assign(assigns, :url, url)

    ~H"""
    <.link
      data-type="dashboard-link"
      patch={@url}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
