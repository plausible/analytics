defmodule PlausibleWeb.CustomerSupport.Live.User do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, :component
  use PlausibleWeb.Live.Flash

  import Ecto.Query
  alias Plausible.Repo

  def update(%{resource_id: resource_id}, socket) do
    user = socket.assigns[:user] || Resource.User.get(resource_id)

    if is_nil(user) do
      redirect(
        socket,
        to: InternalRoutes.customer_support_path(socket, :index)
      )
    else
      form = user |> Plausible.Auth.User.changeset() |> to_form()
      {:ok, assign(socket, user: user, form: form, tab: "overview", keys_count: keys_count(user))}
    end
  end

  def update(%{tab: "keys"}, socket) do
    keys = keys(socket.assigns.user)
    {:ok, assign(socket, tab: "keys", keys: keys)}
  end

  def update(_, socket) do
    {:ok, assign(socket, tab: "overview", keys_count: keys_count(socket.assigns.user))}
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

        <div class="mt-5 flex justify-center sm:mt-0">
          <.input_with_clipboard
            id="user-identifier"
            name="user-identifier"
            label="User Identifier"
            value={@user.id}
          />
        </div>
      </div>

      <div class="mt-4">
        <div class="hidden sm:block">
          <nav
            class="isolate flex divide-x dark:divide-gray-900 divide-gray-200 rounded-lg shadow dark:shadow-1"
            aria-label="Tabs"
          >
            <.tab to="overview" tab={@tab}>Overview</.tab>
            <.tab to="keys" tab={@tab}>
              API Keys ({@keys_count})
            </.tab>
          </nav>
        </div>
      </div>

      <div :if={@tab == "overview"} class="mt-8">
        <.table rows={@user.team_memberships}>
          <:thead>
            <.th>Team</.th>
            <.th>Role</.th>
          </:thead>
          <:tbody :let={membership}>
            <.td>
              <.styled_link patch={"/cs/teams/team/#{membership.team.id}"}>
                {membership.team.name}
              </.styled_link>
            </.td>
            <.td>{membership.role}</.td>
          </:tbody>
        </.table>

        <.form :let={f} for={@form} phx-target={@myself} phx-submit="save-user" class="mt-8">
          <.input type="textarea" field={f[:notes]} label="Notes" />
          <div class="flex justify-between">
            <.button phx-target={@myself} type="submit">
              Save
            </.button>
            <.button
              phx-target={@myself}
              phx-click="delete-user"
              data-confirm="Are you sure you want to delete this user?"
              theme="danger"
            >
              Delete User
            </.button>
          </div>
        </.form>
      </div>

      <div :if={@tab == "keys"} class="mt-8">
        <.table rows={@keys}>
          <:thead>
            <.th>Team</.th>
            <.th>Name</.th>
            <.th>Scopes</.th>
            <.th>Prefix</.th>
          </:thead>
          <:tbody :let={api_key}>
            <.td :if={is_nil(api_key.team)}>N/A</.td>
            <.td :if={api_key.team}>
              <.styled_link patch={"/cs/teams/team/#{api_key.team.id}"}>
                {api_key.team.name}
              </.styled_link>
            </.td>
            <.td>{api_key.name}</.td>
            <.td>
              {api_key.scopes}
            </.td>
            <.td>{api_key.key_prefix}</.td>
          </:tbody>
        </.table>
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
      <div class="text-sm truncate">
        {@resource.object.name} &lt;{@resource.object.email}&gt; <br />
        <br /> Owns {length(@resource.object.owned_teams)} team(s)
      </div>
    </div>
    """
  end

  def handle_event("delete-user", _params, socket) do
    case Plausible.Auth.delete_user(socket.assigns.user) do
      {:ok, :deleted} ->
        {:noreply, push_navigate(put_flash(socket, :success, "User deleted"), to: "/cs")}

      {:error, :active_subscription} ->
        failure(
          socket,
          "User's personal team has an active subscription which must be canceled first."
        )

        {:noreply, socket}

      {:error, :is_only_team_owner} ->
        failure(socket, "The user is the only public team owner on one or more teams.")
        {:noreply, socket}
    end
  end

  def handle_event("save-user", %{"user" => params}, socket) do
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

  defp keys_query(user) do
    from api_key in Plausible.Auth.ApiKey,
      where: api_key.user_id == ^user.id,
      left_join: t in Plausible.Teams.Team,
      on: t.id == api_key.team_id,
      distinct: true,
      order_by: [desc: api_key.id],
      preload: [team: t]
  end

  def keys(user) do
    Repo.all(keys_query(user))
  end

  def keys_count(user) do
    Repo.aggregate(keys_query(user), :count)
  end
end
