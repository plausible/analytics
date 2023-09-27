defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Auth.Invitation

  plug PlausibleWeb.RequireAccountPlug

  @require_owner [:remove_invitation]

  plug PlausibleWeb.AuthorizeSiteAccess, [:owner, :admin] when action in @require_owner

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Plausible.Site.Memberships.accept_invitation(invitation_id, conn.assigns.current_user) do
      {:ok, membership} ->
        conn
        |> put_flash(:success, "You now have access to #{membership.site.domain}")
        |> redirect(to: "/#{URI.encode_www_form(membership.site.domain)}")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
        |> redirect(to: "/sites")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again")
        |> redirect(to: "/sites")
    end
  end

  def reject_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload([:site, :inviter])

    Repo.delete!(invitation)
    notify_invitation_rejected(invitation)

    conn
    |> put_flash(:success, "You have rejected the invitation to #{invitation.site.domain}")
    |> redirect(to: "/sites")
  end

  defp notify_invitation_rejected(%Invitation{role: :owner} = invitation) do
    PlausibleWeb.Email.ownership_transfer_rejected(invitation)
    |> Plausible.Mailer.send()
  end

  defp notify_invitation_rejected(invitation) do
    PlausibleWeb.Email.invitation_rejected(invitation)
    |> Plausible.Mailer.send()
  end

  def remove_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id, site_id: conn.assigns[:site].id)
      |> Repo.preload(:site)

    Repo.delete!(invitation)

    conn
    |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
    |> redirect(to: Routes.site_path(conn, :settings_people, invitation.site.domain))
  end
end
