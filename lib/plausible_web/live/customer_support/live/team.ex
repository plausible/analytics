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
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <div class={[
          team_bg(@resource.object.identifier),
          "rounded-full p-1 flex items-center justify-center"
        ]}>
          <Heroicons.user_group class="h-4 w-4 text-white" />
        </div>
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.name}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
          Team
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm">
        Team identifier: {@resource.object.identifier |> String.slice(0, 8)}
        <br />
        Owned by: {@resource.object.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  def handle_event("change", %{"team" => params}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def team_bg(term) do
    list = [
      "bg-blue-500",
      "bg-blue-600",
      "bg-blue-700",
      "bg-blue-800",
      "bg-indigo-500",
      "bg-indigo-600",
      "bg-indigo-700",
      "bg-indigo-800",
      "bg-cyan-500",
      "bg-cyan-600",
      "bg-cyan-700",
      "bg-cyan-800",
      "bg-red-500",
      "bg-red-600",
      "bg-red-700",
      "bg-red-800",
      "bg-green-500",
      "bg-green-600",
      "bg-green-700",
      "bg-green-800",
      "bg-yellow-500",
      "bg-yellow-600",
      "bg-yellow-700",
      "bg-yellow-800",
      "bg-orange-500",
      "bg-orange-600",
      "bg-orange-700",
      "bg-orange-800",
      "bg-purple-500",
      "bg-purple-600",
      "bg-purple-700",
      "bg-purple-800",
      "bg-gray-500",
      "bg-gray-600",
      "bg-gray-700",
      "bg-gray-800",
      "bg-emerald-500",
      "bg-emerald-600",
      "bg-emerald-700",
      "bg-emerald-800"
    ]

    idx = :erlang.phash2(term, length(list))
    Enum.at(list, idx)
  end
end
