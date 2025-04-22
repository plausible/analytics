defmodule PlausibleWeb.CustomerSupport.LiveUser do
  use PlausibleWeb, :live_component

  def get(id) do
    Plausible.Repo.get!(Plausible.Auth.User, id)
    |> Plausible.Repo.preload(owned_teams: :sites)
  end

  def update(assigns, socket) do
    user = get(assigns.resource_id)
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

  def handle_event("delete", _params, socket) do
    IO.inspect(socket.assigns)
    raise "delete"
  end
end
