defmodule PlausibleWeb.InvitationController do
  use PlausibleWeb, :controller

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.Plugs.AuthorizeSiteAccess,
       [:owner, :editor, :admin] when action in [:remove_invitation]

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    case Plausible.Site.Memberships.accept_invitation(invitation_id, conn.assigns.current_user) do
      {:ok, membership} ->
        conn
        |> put_flash(:success, "You now have access to #{membership.site.domain}")
        |> redirect(external: "/#{URI.encode_www_form(membership.site.domain)}")

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already accepted")
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
      {:ok, invitation} ->
        conn
        |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
        |> redirect(external: Routes.site_path(conn, :settings_people, invitation.site.domain))

      {:error, :invitation_not_found} ->
        conn
        |> put_flash(:error, "Invitation missing or already removed")
        |> redirect(external: Routes.site_path(conn, :settings_people, conn.assigns.site.domain))
    end
  end
end
