defmodule PlausibleWeb.CustomerSupport.Live.User do
  use Plausible.CustomerSupport.Resource, :component
  use PlausibleWeb.Live.Flash

  def update(assigns, socket) do
    user = Resource.User.get(assigns.resource_id)
    form = user |> Plausible.Auth.User.changeset() |> to_form()
    {:ok, assign(socket, user: user, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@form} phx-target={@myself} phx-submit="change">
        <.tile>
          <:title>
            <div class="flex items-center"><Heroicons.user class="h-4 w-4 mr-2" />
              {@user.name}</div>
          </:title>
          <:subtitle>
            e-mail: {@user.email}
            <span :if={@user.previous_email}>
              / previous e-mail: {@user.previous_email}
            </span>
          </:subtitle>
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
        </.tile>
        <.tile>
          <:title>Notes</:title>
          <:subtitle></:subtitle>
          <textarea
            rows="8"
            class="block w-full border-gray-300 dark:border-gray-700 resize-none shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-900 dark:text-gray-300"
            name={f[:notes].name}
          >{f[:notes].value}</textarea>
        </.tile>
        <.tile>
          <:title>Actions</:title>
          <:subtitle></:subtitle>

          <.button phx-target={@myself} type="submit">
            Save
          </.button>
          <.button phx-target={@myself} phx-click="delete" theme="danger">
            Delete
          </.button>
        </.tile>
      </.form>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <img
          src={Plausible.Auth.User.profile_img_url(@resource.object)}
          class="w-4 rounded-full bg-gray-300"
        />
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

  def handle_event("delete", _params, socket) do
    raise "delete"
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
