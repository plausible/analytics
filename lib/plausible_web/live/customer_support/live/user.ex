defmodule PlausibleWeb.CustomerSupport.Live.User do
  use Plausible.CustomerSupport.Resource, :component

  def update(assigns, socket) do
    user = Resource.User.get(assigns.resource_id)
    {:ok, assign(socket, user: user)}
  end

  def render(assigns) do
    ~H"""
    <div id="user">
      User: {@user.name} &lt;{@user.email}&gt;
      <div :for={t <- @user.owned_teams}>
        <.styled_link phx-click="open" phx-value-id={t.id} phx-value-type="team">
          {t.name}
        </.styled_link>
        <div class="ml-4">
          <div :for={s <- Enum.take(t.sites, 10)}>
            <.styled_link phx-click="open" phx-value-id={s.id} phx-value-type="site">
              {s.domain}
            </.styled_link>
          </div>

          <div :if={length(t.sites) > 10}>
            ...
          </div>
        </div>
      </div>

      <.button phx-target={@myself} phx-click="delete" theme="danger">
        Delete
      </.button>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex items-center">
      <Heroicons.user class="h-6 w-6 mr-4" />
      {@resource.object.name} &lt;{@resource.object.email}&gt;
    </div>
    """
  end

  def handle_event("delete", _params, socket) do
    raise "delete"
  end
end
