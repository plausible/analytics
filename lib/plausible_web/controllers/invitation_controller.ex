defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.Plugs.AuthorizeSiteAccess,
       [:owner, :editor, :admin] when action in [:remove_invitation]

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    current_user = conn.assigns.current_user
    team = conn.assigns.current_team

    case Plausible.Site.Memberships.accept_invitation(invitation_id, current_user, team) do
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
          |> redirect(external: "/#{URI.encode_www_form(site.domain)}")
        else
          conn
          |> put_flash(:success, "You now have access to \"#{team.name}\" team")
          |> redirect(external: "/sites")
        end

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
        |> redirect(to: "/sites")

      {:error, :already_other_team_member} ->
        conn
        |> put_flash(:error, "You already are a team member in another team")
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

  def reject_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Plausible.Site.Memberships.reject_invitation(invitation_id, conn.assigns.current_user) do
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

  def remove_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Plausible.Site.Memberships.remove_invitation(invitation_id, conn.assigns.site) do
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
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already removed")
        |> redirect(external: Routes.site_path(conn, :settings_people, conn.assigns.site.domain))
    end
  end

  def remove_team_invitation(conn, %{"invitation_id" => invitation_id}) do
    %{my_team: team, current_user: current_user} = conn.assigns

    case Plausible.Teams.Invitations.Remove.remove(team, invitation_id, current_user) do
      {:ok, invitation} ->
        conn
        |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
        |> redirect(external: Routes.settings_path(conn, :team_general))

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already removed")
        |> redirect(external: Routes.settings_path(conn, :team_general))

      {:error, :permission_denied} ->
        conn
        |> put_flash(:error, "You are not allowed to remove invitations")
        |> redirect(to: Routes.settings_path(conn, :team_general))
    end
  end
end
