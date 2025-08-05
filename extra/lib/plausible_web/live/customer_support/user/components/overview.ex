defmodule PlausibleWeb.CustomerSupport.User.Components.Overview do
  @moduledoc """
  User overview component - handles user settings, team memberships, and user management
  """
  use PlausibleWeb, :live_component

  def update(%{user: user}, socket) do
    form = user |> Plausible.Auth.User.changeset() |> to_form()
    {:ok, assign(socket, user: user, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
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
    """
  end

  def handle_event("delete-user", _params, socket) do
    user = socket.assigns.user

    case Plausible.Auth.delete_user(user) do
      {:ok, _} ->
        send(self(), {:success, "User deleted successfully"})
        send(self(), {:navigate, Routes.customer_support_path(socket, :index), nil})
        {:noreply, socket}

      {:error, :subscription_active} ->
        send(self(), {:error, "Cannot delete user with active subscription"})
        {:noreply, socket}

      {:error, _} ->
        send(self(), {:error, "Failed to delete user"})
        {:noreply, socket}
    end
  end

  def handle_event("save-user", %{"user" => params}, socket) do
    user = socket.assigns.user

    case Plausible.Auth.User.changeset(user, params) |> Plausible.Repo.update() do
      {:ok, updated_user} ->
        form = updated_user |> Plausible.Auth.User.changeset() |> to_form()
        send(self(), {:success, "User updated successfully"})
        {:noreply, assign(socket, user: updated_user, form: form)}

      {:error, changeset} ->
        form = changeset |> to_form()
        send(self(), {:error, "Failed to update user"})
        {:noreply, assign(socket, form: form)}
    end
  end
end
