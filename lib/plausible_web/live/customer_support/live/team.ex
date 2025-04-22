defmodule PlausibleWeb.CustomerSupport.Live.Team do
  use Plausible.CustomerSupport.Resource, :component

  def update(assigns, socket) do
    team = Resource.Team.get(assigns.resource_id)
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)
    {:ok, assign(socket, team: team, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div id="site">
        <div>
          {@team.name} owned by
          <div :for={o <- @team.owners}>
            <.styled_link phx-click="open" phx-value-id={o.id} phx-value-type="user">
              {o.name} {o.email}
            </.styled_link>
          </div>
          <.form :let={f} for={@form} phx-submit="change" phx-target={@myself}>
            <.input field={f[:trial_expiry_date]} />
            <.button type="submit">
              Change
            </.button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex items-center">
      <Heroicons.user_group class="h-6 w-6 mr-4" />
      {@resource.object.name} ({@resource.object.identifier |> String.slice(0, 8)})
      owned by {@resource.object.owners |> Enum.map(& &1.name) |> Enum.join(", ")}
    </div>
    """
  end

  def handle_event("change", %{"team" => params}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

      {:error, changeset} ->
        IO.inspect(:error)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
