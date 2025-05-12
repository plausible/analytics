defmodule PlausibleWeb.CustomerSupport.Live.User do
  use Plausible.CustomerSupport.Resource, :component
  use PlausibleWeb.Live.Flash

  def update(assigns, socket) do
    user = socket.assigns[:user] || Resource.User.get(assigns.resource_id)
    form = user |> Plausible.Auth.User.changeset() |> to_form()
    {:ok, assign(socket, user: user, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex sm:space-x-5">
          <div class="shrink-0">
            <div class="rounded-full p-1 flex items-center justify-center">
              <img
                src={Plausible.Auth.User.profile_img_url(@user)}
                class="w-14 rounded-full bg-gray-300"
              />
            </div>
          </div>
          <div class="mt-4 text-center sm:mt-0 sm:pt-1 sm:text-left">
            <p class="text-xl font-bold sm:text-2xl">
              {@user.name}
            </p>
            <p class="text-sm font-medium">
              <span>{@user.email}</span>

              <span :if={@user.previous_email}>(previously: {@user.previous_email})</span>
            </p>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <.table rows={@user.team_memberships}>
          <:thead>
            <.th>Team</.th>
            <.th>Role</.th>
          </:thead>
          <:tbody :let={membership}>
            <.td>
              <.styled_link phx-click="open" phx-value-id={membership.team.id} phx-value-type="team">
                {membership.team.name}
              </.styled_link>
            </.td>
            <.td>{membership.role}</.td>
          </:tbody>
        </.table>

        <.form :let={f} for={@form} phx-target={@myself} phx-submit="change" class="mt-8">
          <.input type="textarea" field={f[:notes]} label="Notes" />
          <.button phx-target={@myself} type="submit">
            Save
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
        <img src={Plausible.Auth.User.profile_img_url(@resource.object)} class="h-5 w-5 rounded-full" />
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.name}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
          User
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm">
        {@resource.object.name} &lt;{@resource.object.email}&gt; <br />
        Owns {length(@resource.object.owned_teams)} team(s)
      </div>
    </div>
    """
  end

  def handle_event("change", %{"user" => params}, socket) do
    changeset = Plausible.Auth.User.changeset(socket.assigns.user, params)

    case Plausible.Repo.update(changeset) do
      {:ok, user} ->
        success(socket, "User updated")
        {:noreply, assign(socket, user: user, form: to_form(changeset))}

      {:error, changeset} ->
        failure(socket, inspect(changeset.errors))
        send(socket.root_pid, {:failure, inspect(changeset.errors)})
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
