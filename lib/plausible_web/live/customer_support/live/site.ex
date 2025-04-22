defmodule PlausibleWeb.CustomerSupport.Live.Site do
  use Plausible.CustomerSupport.Resource, :component

  def update(assigns, socket) do
    site = Resource.Site.get(assigns.resource_id)
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

  def render_result(assigns) do
    ~H"""
    <div class="flex items-center">
      <Heroicons.newspaper class="h-6 w-6 mr-4" />
      <div>
        <strong>{@resource.object.domain}</strong>
        part of {@resource.object.team.name} owned by {@resource.object.team.owners
        |> Enum.map(& &1.name)
        |> Enum.join(",")}
      </div>
    </div>
    """
  end
end
