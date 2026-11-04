defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller

  alias Plausible.Teams

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.Plugs.AuthorizeSiteAccess,
       [:owner, :admin] when action in [:remove_invitation]

  # capability:begin
  # id: accept_invitation@ui_session
  # action: accept_invitation
  # transport: ui_session
  # entry: POST /sites/invitations/:invitation_id/accept and POST /settings/team/invitations/:invitation_id/accept (router.ex scope "/", pipe_through [:browser, :csrf])
  # handler: PlausibleWeb.InvitationController.accept_invitation/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: Teams.Invitations.Accept (invitation must be for the current user)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: One handler for guest, team and site transfer invitations
  # capability:end
  def accept_invitation(conn, %{"invitation_id" => invitation_id} = params) do
    current_user = conn.assigns.current_user
    team = conn.assigns.current_team

    result =
      if params["skip_site_members_transfer"] == "true" do
        Teams.Invitations.Accept.accept_transfer_no_members(invitation_id, current_user, team)
      else
        Teams.Invitations.Accept.accept(invitation_id, current_user, team)
      end

    case result do
      {:ok, result} ->
        team = result.team

        site =
          case result do
            %{guest_memberships: [guest_membership]} ->
              Plausible.Repo.preload(guest_membership, :site).site

            %{guest_memberships: []} ->
              nil

            %{site: site} ->
              site
          end

        if site do
          conn
          |> put_flash(:success, "You now have access to #{site.domain}")
          |> redirect(to: stats_path(site.domain))
        else
          conn
          |> put_flash(:success, "You now have access to \"#{team.name}\" team")
          |> redirect(to: ~p"/sites?#{[__team: team.identifier]}")
        end

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
        |> redirect(to: "/sites")

      {:error, :transfer_to_self} ->
        conn
        |> put_flash(:error, "The site is already in the current team")
        |> redirect(to: "/sites")

      {:error, :permission_denied} ->
        conn
        |> put_flash(:error, "You can't add sites in the current team")
        |> redirect(to: "/sites")

      {:error, :no_plan} ->
        conn
        |> put_flash(:error, "No existing subscription")
        |> redirect(to: "/sites")

      {:error, {:over_plan_limits, limits}} ->
        conn
        |> put_flash(
          :error,
          "Plan limits exceeded: #{PlausibleWeb.TextHelpers.pretty_list(limits)}."
        )
        |> redirect(to: "/sites")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again")
        |> redirect(to: "/sites")
    end
  end

  # capability:begin
  # id: reject_invitation@ui_session
  # action: reject_invitation
  # transport: ui_session
  # entry: POST /sites/invitations/:invitation_id/reject and POST /settings/team/invitations/:invitation_id/reject (router.ex scope "/", pipe_through [:browser, :csrf])
  # handler: PlausibleWeb.InvitationController.reject_invitation/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: invitation must be for the current user
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: inferred
  # capability:end
  def reject_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Teams.Invitations.Reject.reject(invitation_id, conn.assigns.current_user) do
      {:ok, _invitation} ->
        conn
        |> put_flash(:success, "You have rejected the invitation")
        |> redirect(to: "/sites")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
        |> redirect(to: "/sites")
    end
  end

  # capability:begin
  # id: cancel_guest_invitation@ui_session
  # action: cancel_guest_invitation
  # transport: ui_session
  # entry: DELETE /sites/:domain/invitations/:invitation_id (router.ex scope "/", pipe_through [:browser, :csrf])
  # handler: PlausibleWeb.InvitationController.remove_invitation/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin]
  # current_role_enforced_by: InvitationController plug AuthorizeSiteAccess [:owner, :admin]
  # current_feature_gate: none
  # proposed_scope: access:write
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: Also cancels pending site transfers; the Sites API covers this inside remove_guest
  # capability:end
  def remove_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Teams.Invitations.RemoveFromSite.remove(invitation_id, conn.assigns.site) do
      {:ok, invitation_or_transfer} ->
        {site, email} =
          case invitation_or_transfer do
            %Plausible.Teams.GuestInvitation{} = guest_invitation ->
              {guest_invitation.site, guest_invitation.team_invitation.email}

            %Plausible.Teams.SiteTransfer{} = site_transfer ->
              {site_transfer.site, site_transfer.email}
          end

        conn
        |> put_flash(:success, "You have removed the invitation for #{email}")
        |> redirect(to: ~p"/#{site.domain}/settings/people")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already removed")
        |> redirect(to: ~p"/#{conn.assigns.site.domain}/settings/people")
    end
  end

  # capability:begin
  # id: cancel_team_invitation@ui_session
  # action: cancel_team_invitation
  # transport: ui_session
  # entry: DELETE /settings/team/invitations/:invitation_id (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.InvitationController.remove_team_invitation/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin]
  # current_role_enforced_by: Invitations.RemoveFromTeam.remove -> check_can_remove_invitation (owner, admin)
  # current_feature_gate: none
  # proposed_scope: access:write
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: TeamManagement "remove-member" covers the same for pending invitations
  # capability:end
  def remove_team_invitation(conn, %{"invitation_id" => invitation_id}) do
    %{current_team: team, current_user: current_user} = conn.assigns

    case Teams.Invitations.RemoveFromTeam.remove(team, invitation_id, current_user) do
      {:ok, invitation} ->
        conn
        |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
        |> redirect(to: ~p"/settings/team/general")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already removed")
        |> redirect(to: ~p"/settings/team/general")

      {:error, :permission_denied} ->
        conn
        |> put_flash(:error, "You are not allowed to remove invitations")
        |> redirect(to: ~p"/settings/team/general")
    end
  end
end
