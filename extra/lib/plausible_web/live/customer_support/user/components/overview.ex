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
            <.styled_link patch={~p"/cs/teams/team/#{membership.team.id}"}>
              {membership.team.name}
            </.styled_link>
          </.td>
          <.td>{membership.role}</.td>
        </:tbody>
      </.table>

      <.form :let={f} for={@form} phx-target={@myself} phx-submit="save-user" class="mt-8">
        <.input type="textarea" field={f[:notes]} label="Notes" />
        <div class="flex justify-between mt-6">
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

  # capability:begin
  # id: cs_delete_user@ui_session
  # action: cs_delete_user
  # transport: ui_session
  # entry: live /cs/users/user/:id?tab=overview handle_event "delete-user"
  # handler: PlausibleWeb.CustomerSupport.User.Components.Overview.handle_event/3
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:delete
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Refused with an active subscription
  # capability:end
  def handle_event("delete-user", _params, socket) do
    user = socket.assigns.user

    case Plausible.Auth.delete_user(user) do
      {:ok, _} ->
        navigate_with_success(~p"/cs", "User deleted")
        {:noreply, socket}

      {:error, :active_subscription} ->
        failure("Cannot delete user with active subscription")
        {:noreply, socket}

      {:error, reason} ->
        failure("Failed to delete user: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  # capability:begin
  # id: cs_force_disable_2fa@ui_session
  # action: cs_force_disable_2fa
  # transport: ui_session
  # entry: live /cs/users/user/:id?tab=overview handle_event "force-disable-2fa"
  # handler: PlausibleWeb.CustomerSupport.User.Components.Overview.handle_event/3
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Removes a second factor without the user; account security, keep session only
  # capability:end
  def handle_event("force-disable-2fa", _params, socket) do
    user = socket.assigns.user

    {:ok, updated_user} = TOTP.force_disable(user)
    send(self(), {:success, "2FA has been force disabled for this user"})
    {:noreply, assign(socket, user: updated_user)}
  end

  # capability:begin
  # id: cs_update_user@ui_session
  # action: cs_update_user
  # transport: ui_session
  # entry: live /cs/users/user/:id?tab=overview handle_event "save-user"
  # handler: PlausibleWeb.CustomerSupport.User.Components.Overview.handle_event/3
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: User.changeset casts email, name, email_verified, theme and notes, so a token could change a user's email and mark it verified, which is an account takeover; keep session only or split notes into cs:write
  # capability:end
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
