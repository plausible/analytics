defmodule PlausibleWeb.CustomerSupport.User.Components.Overview do
  @moduledoc """
  User overview component - handles user settings, team memberships, and user management
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  alias Plausible.Auth.TOTP

  def update(%{user: user}, socket) do
    form = user |> Plausible.Auth.User.changeset() |> to_form()
    {:ok, assign(socket, user: user, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <div class="mb-8">
        <div class="mt-4 flex items-center justify-between">
          <div>
            <span class="text-sm">
              Two-Factor Authentication:
              <span class={[
                "text-sm font-medium",
                if(TOTP.enabled?(@user), do: "text-green-600", else: "text-gray-500")
              ]}>
                {if TOTP.enabled?(@user), do: "Enabled", else: "Disabled"}
              </span>
            </span>
          </div>
        </div>
      </div>

      <.table rows={@user.team_memberships}>
        <:thead>
          <.th>Team</.th>
          <.th>Role</.th>
        </:thead>
        <:tbody :let={membership}>
          <.td>
            <.styled_link patch={
              Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, membership.team.id)
            }>
              {membership.team.name}
            </.styled_link>
          </.td>
          <.td>{membership.role}</.td>
        </:tbody>
      </.table>

      <.form :let={f} for={@form} phx-target={@myself} phx-submit="save-user" class="mt-8">
        <.input type="textarea" field={f[:notes]} label="Notes" />
        <div class="flex justify-between">
          <div>
            <.button phx-target={@myself} type="submit">
              Save
            </.button>
          </div>
          <div class="flex gap-2">
            <.button
              :if={TOTP.enabled?(@user)}
              phx-target={@myself}
              phx-click="force-disable-2fa"
              data-confirm="Are you sure you want to force disable 2FA for this user? This action cannot be undone."
              theme="danger"
            >
              Force Disable 2FA
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
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("delete-user", _params, socket) do
    user = socket.assigns.user

    case Plausible.Auth.delete_user(user) do
      {:ok, _} ->
        navigate_with_success(Routes.customer_support_path(socket, :index), "User deleted")
        {:noreply, socket}

      {:error, :active_subscription} ->
        failure("Cannot delete user with active subscription")
        {:noreply, socket}

      {:error, reason} ->
        failure("Failed to delete user: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("force-disable-2fa", _params, socket) do
    user = socket.assigns.user

    case TOTP.force_disable(user) do
      {:ok, updated_user} ->
        send(self(), {:success, "2FA has been force disabled for this user"})
        {:noreply, assign(socket, user: updated_user)}

      {:error, reason} ->
        send(self(), {:error, "Failed to disable 2FA: #{reason}"})
        {:noreply, socket}
    end
  end

  def handle_event("save-user", %{"user" => params}, socket) do
    user = socket.assigns.user

    case Plausible.Auth.User.changeset(user, params) |> Plausible.Repo.update() do
      {:ok, updated_user} ->
        form = updated_user |> Plausible.Auth.User.changeset() |> to_form()
        success("User updated successfully")
        {:noreply, assign(socket, user: updated_user, form: form)}

      {:error, changeset} ->
        form = changeset |> to_form()
        failure("Failed to update user")
        {:noreply, assign(socket, form: form)}
    end
  end
end
