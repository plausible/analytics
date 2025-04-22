defmodule PlausibleWeb.CustomerSupport.LiveTeam do
  use PlausibleWeb, :live_component

  def get(id) do
    Plausible.Repo.get(Plausible.Teams.Team, id)
    |> Plausible.Repo.preload(:owners)
  end

  def update(assigns, socket) do
    team = get(assigns.resource_id)
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

  def handle_event("change", %{"team" => params}, socket) do
    IO.inspect(params, label: :change)

    changeset =
      Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)
      |> IO.inspect(label: :cs)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

      {:error, changeset} ->
        IO.inspect(:error)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
