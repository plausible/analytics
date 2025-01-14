defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.Plugs.AuthorizeSiteAccess,
       [:owner, :editor, :admin] when action in [:remove_invitation]

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Plausible.Site.Memberships.accept_invitation(invitation_id, conn.assigns.current_user) do
      {:ok, result} ->
        site =
          case result do
            %{guest_memberships: [guest_membership]} ->
              Plausible.Repo.preload(guest_membership, :site).site

            %{site: site} ->
              site
          end

        conn
        |> put_flash(:success, "You now have access to #{site.domain}")
        |> redirect(external: "/#{URI.encode_www_form(site.domain)}")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
        |> redirect(to: "/sites")

      {:error, :already_other_team_member} ->
        conn
        |> put_flash(:error, "You already are a team member in another team")
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
      {:ok, invitation} ->
        conn
        |> put_flash(:success, "You have rejected the invitation to #{invitation.site.domain}")
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
end
