defmodule PlausibleWeb.Live.TeamManagement do
  @moduledoc """
  Live view for applying team membership adjustments.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias Plausible.Teams.TeamRolePermissions
  alias Plausible.Auth.User
  import PlausibleWeb.Live.Components.Team

  alias Plausible.Teams.Management.Layout

  def mount(_params, _session, socket) do
    {:ok, reset(socket)}
  end

  defp reset(%{assigns: %{current_user: current_user, current_team: current_team}} = socket) do
    {:ok, my_role} = Teams.Memberships.team_role(current_team, current_user)

    layout = Layout.init(current_team)
    team_members_limit = Plausible.Teams.Billing.team_member_limit(current_team)

    assign(socket,
      team_members_limit: team_members_limit,
      layout: layout,
      my_role: my_role,
      input_email: ""
    )
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <PlausibleWeb.Components.Billing.Notice.limit_exceeded
      :if={@team_members_limit != 0 and at_limit?(@layout, @team_members_limit)}
      current_user={@current_user}
      current_team={@current_team}
      limit={@team_members_limit}
      resource="members"
      class="mb-4"
    />
    <div>
      <.form id="team-layout-form" for={} phx-submit="input-invitation" phx-change="form-changed">
        <div class="flex gap-x-3 mb-8">
          <div class="flex-1">
            <.input
              name="input-email"
              type="email"
              value={@input_email}
              placeholder="Enter e-mail"
              phx-debounce={200}
              readonly={
                at_limit?(@layout, @team_members_limit) or
                  not TeamRolePermissions.can_manage_team?(@my_role)
              }
            />
          </div>

          <.role_select_input
            id="input-role-picker"
            name="input-role"
            role={:viewer}
            my_role={@my_role}
          />

          <.button
            id="invite-member"
            type="submit"
            disabled={
              at_limit?(@layout, @team_members_limit) or
                not TeamRolePermissions.can_manage_team?(@my_role)
            }
          >
            Invite
          </.button>
        </div>
      </.form>

      <div id="member-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.role != :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          me?={entry.id == @current_user.id}
          pending?={entry.type in [:invitation_pending, :invitation_sent]}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
          disabled={
            (entry.role == :owner && Layout.owners_count(@layout) == 1) or
              not TeamRolePermissions.can_manage_team?(@my_role)
          }
        />
      </div>

      <div :if={Layout.has_guests?(@layout)} class="flex items-center mt-4 mb-4" id="guests-hr">
        <hr class="grow border-t border-gray-200 dark:border-gray-700" />
        <span class="mx-4 text-gray-500 text-sm">
          Guests
        </span>
        <hr class="grow border-t border-gray-200 dark:border-gray-700" />
      </div>

      <div :if={Layout.has_guests?(@layout)} id="guest-list">
        <.member
          :for={{email, entry} <- Layout.sorted_for_display(@layout)}
          :if={entry.role == :guest}
          user={%User{email: entry.email, name: entry.name}}
          role={entry.role}
          label={entry_label(entry, @current_user)}
          pending?={entry.type in [:invitation_pending, :invitation_sent]}
          my_role={@my_role}
          remove_disabled={not Layout.removable?(@layout, email)}
          role_change_disabled={entry.type in [:invitation_pending, :invitation_sent]}
          disabled={not TeamRolePermissions.can_manage_team?(@my_role)}
        />
      </div>
    </div>
    """
  end

  @permission_denied_message "Permission denied"
  @not_found_message "This member or invitation doesn't exist anymore. Please reload the page"
  @only_one_owner_message "The team has to have at least one owner"

  def handle_event("form-changed", params, socket) do
    {:noreply, assign(socket, input_email: params["input-email"])}
  end

  def handle_event(
        "input-invitation",
        %{"input-email" => email, "input-role" => role},
        %{assigns: %{current_team: team, current_user: current_user}} = socket
      ) do
    email = String.trim(email)
    role = role_to_atom(role)
    socket = assign(socket, input_email: email)

    socket =
      case Teams.Invitations.InviteToTeam.invite_all(reload(team), current_user, [
             %{email: email, role: role}
           ]) do
        {:ok, invitations} ->
          Teams.Invitations.InviteToTeam.send_invitation_emails(invitations)
          socket |> reset() |> put_live_flash(:success, "#{email} has been invited")

        {:error, reason} when reason in [:invalid_email, :already_a_member, :already_invited] ->
          put_live_flash(
            socket,
            :error,
            "Make sure the e-mail is valid and not already taken by an existing member or invitation"
          )

        {:error, :already_a_guest} ->
          put_live_flash(
            socket,
            :error,
            "This e-mail belongs to a guest. Please change their role below, or delete and invite them again."
          )

        {:error, :already_invited_guest} ->
          put_live_flash(
            socket,
            :error,
            "This e-mail is already invited as a guest. To invite them to the team, please delete the guest invitation first."
          )

        {:error, :permission_denied} ->
          put_live_flash(socket, :error, @permission_denied_message)

        {:error, {:over_limit, limit}} ->
          put_live_flash(
            socket,
            :error,
            "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
          )
      end

    {:noreply, socket}
  end

  def handle_event("remove-member", %{"email" => email}, %{assigns: %{layout: layout}} = socket) do
    {:noreply, remove(socket, Map.fetch!(layout, email))}
  end

  def handle_event(
        "update-role",
        %{"email" => email, "role" => role},
        %{assigns: %{layout: layout}} = socket
      ) do
    {:noreply, update_role(socket, Map.fetch!(layout, email), role_to_atom(role))}
  end

  defp remove(socket, %Layout.Entry{type: :membership, meta: membership}) do
    %{current_team: team, current_user: current_user} = socket.assigns
    myself? = membership.user.id == current_user.id

    case Teams.Memberships.Remove.remove(reload(team), membership.user.id, current_user) do
      {:ok, _} when myself? ->
        socket
        |> put_flash(:success, "You have left the team")
        |> redirect(to: ~p"/sites?#{[__team: "none"]}")

      {:ok, _} ->
        socket
        |> reset()
        |> put_live_flash(:success, "#{membership.user.email} has been removed from the team")

      {:error, :membership_not_found} ->
        put_live_flash(socket, :error, @not_found_message)

      {:error, reason} when reason in [:permission_denied, :not_a_member] ->
        put_live_flash(socket, :error, @permission_denied_message)

      {:error, :only_one_owner} ->
        put_live_flash(socket, :error, @only_one_owner_message)
    end
  end

  defp remove(socket, %Layout.Entry{type: :invitation_sent, meta: invitation}) do
    %{current_team: team, current_user: current_user} = socket.assigns

    case Teams.Invitations.RemoveFromTeam.remove(
           reload(team),
           invitation.invitation_id,
           current_user
         ) do
      {:ok, _} ->
        socket
        |> reset()
        |> put_live_flash(:success, "The invitation for #{invitation.email} has been removed")

      {:error, :invitation_not_found} ->
        put_live_flash(socket, :error, @not_found_message)

      {:error, reason} when reason in [:permission_denied, :not_a_member] ->
        put_live_flash(socket, :error, @permission_denied_message)
    end
  end

  defp update_role(socket, %Layout.Entry{type: :membership, meta: membership}, role) do
    %{current_team: team, current_user: current_user} = socket.assigns

    demoting_myself? =
      membership.user.id == current_user.id and
        not TeamRolePermissions.can_manage_team?(role)

    case Teams.Memberships.UpdateRole.update(
           reload(team),
           membership.user.id,
           to_string(role),
           current_user
         ) do
      {:ok, _} when demoting_myself? ->
        socket
        |> put_flash(:success, "Your role has been changed to #{role_name(role)}")
        |> redirect(to: ~p"/settings/team/general?#{[__team: team.identifier]}")

      {:ok, _} ->
        socket
        |> reset()
        |> put_live_flash(
          :success,
          "#{membership.user.email}'s role has been changed to #{role_name(role)}"
        )
        |> animate_role_change(membership.user.email)

      {:error, :membership_not_found} ->
        put_live_flash(socket, :error, @not_found_message)

      {:error, :permission_denied} ->
        put_live_flash(socket, :error, @permission_denied_message)

      {:error, :only_one_owner} ->
        put_live_flash(socket, :error, @only_one_owner_message)

      {:error, :disabled_2fa} ->
        put_live_flash(socket, :error, "User must have 2FA enabled to become an owner")
    end
  end

  defp update_role(socket, %Layout.Entry{type: :invitation_sent, meta: invitation}, role) do
    %{current_team: team, current_user: current_user} = socket.assigns

    case Teams.Invitations.UpdateRole.update(
           reload(team),
           invitation.invitation_id,
           role,
           current_user
         ) do
      {:ok, _} ->
        socket
        |> reset()
        |> put_live_flash(
          :success,
          "The invitation for #{invitation.email} now has the #{role_name(role)} role"
        )
        |> animate_role_change(invitation.email)

      {:error, :invitation_not_found} ->
        put_live_flash(socket, :error, @not_found_message)

      {:error, :guest_invitation} ->
        put_live_flash(
          socket,
          :error,
          "A guest invitation can't be changed into a team invitation. Remove it and send a team invitation instead"
        )

      {:error, :permission_denied} ->
        put_live_flash(socket, :error, @permission_denied_message)
    end
  end

  defp animate_role_change(socket, email) do
    push_event(socket, "js-exec", %{
      to: "#member-row-#{:erlang.phash2(email)}",
      attr: "data-role-changed"
    })
  end

  defp reload(team), do: Plausible.Repo.reload!(team)

  defp role_name(role), do: role |> to_string() |> String.capitalize()

  defp entry_label(%Layout.Entry{role: :guest, type: :membership}, _), do: nil
  defp entry_label(%Layout.Entry{type: :invitation_pending}, _), do: "Invitation pending"
  defp entry_label(%Layout.Entry{type: :invitation_sent}, _), do: "Invitation sent"

  defp entry_label(%Layout.Entry{meta: %{user: %{id: id, type: :sso}}}, %{id: id}),
    do: "You (SSO)"

  defp entry_label(%Layout.Entry{meta: %{user: %{id: id}}}, %{id: id}), do: "You"
  defp entry_label(%Layout.Entry{meta: %{user: %{type: :sso}}}, _), do: "SSO"
  defp entry_label(_, _), do: nil

  def at_limit?(layout, limit) do
    not Plausible.Billing.Quota.below_limit?(
      Layout.active_count(layout) - 1,
      limit
    )
  end
end
