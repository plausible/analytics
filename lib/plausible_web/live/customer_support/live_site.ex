defmodule PlausibleWeb.CustomerSupport.LiveSite do
  use PlausibleWeb, :live_component

  def get(id) do
    Plausible.Repo.get(Plausible.Site, id)
    |> Plausible.Repo.preload(:team)
  end

  def update(assigns, socket) do
    site = get(assigns.resource_id)
    {:ok, assign(socket, site: site)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div id="site">
        <div>
          {@site.domain} owned by
          <.styled_link phx-click="open" phx-value-id={@site.team.id} phx-value-type="team">
            {@site.team.name}
          </.styled_link>
        </div>
      </div>
    </div>
    """
  end
end
