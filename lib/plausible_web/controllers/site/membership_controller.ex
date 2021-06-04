defmodule PlausibleWeb.Site.MembershipController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Ecto.Multi
  alias Plausible.Sites
  alias Plausible.Site.Membership
  alias Plausible.Auth.Invitation

  plug PlausibleWeb.RequireAccountPlug

  def invite_member_form(conn, %{"website" => site_domain}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)

    render(
      conn,
      "invite_member_form.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def invite_member(conn, %{"website" => site_domain, "email" => email, "role" => role}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)
    user = Plausible.Auth.find_user_by(email: email)

    if user do
      Invitation.new(%{
        email: email,
        role: role,
        site_id: site.id
      })
      |> Repo.insert!()

      conn
      |> put_flash(:success, "#{email} has been invited to #{site_domain} as a #{role}")
      |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    else
      invitation =
        Invitation.new(%{
          email: email,
          role: role,
          site_id: site.id
        })
        |> Repo.insert!()

      email_template =
        PlausibleWeb.Email.new_user_invitation(
          email,
          conn.assigns[:current_user],
          site,
          invitation
        )

      Plausible.Mailer.send_email(email_template)

      conn
      |> put_flash(:success, "#{email} has been invited to #{site_domain} as a #{role}")
      |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    end
  end

  def update_role(conn, %{"id" => id, "new_role" => new_role}) do
    membership =
      Repo.get!(Membership, id)
      |> Repo.preload([:site, :user])
      |> Membership.changeset(%{role: new_role})
      |> Repo.update!()

    conn
    |> put_flash(:success, "#{membership.user.name} is now a #{new_role}")
    |> redirect(to: "/#{URI.encode_www_form(membership.site.domain)}/settings/general")
  end

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload(:site)

    user = conn.assigns[:current_user]

    membership_changeset =
      Membership.changeset(%Membership{}, %{
        user_id: user.id,
        site_id: invitation.site.id,
        role: invitation.role
      })

    result =
      Multi.new()
      |> Multi.insert(:membership, membership_changeset)
      |> Multi.delete(:invitation, invitation)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:success, "You now have access to #{invitation.site.domain}")
        |> redirect(to: "/#{URI.encode_www_form(invitation.site.domain)}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again")
        |> redirect(to: "/sites")
    end
  end

  def reject_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload(:site)

    Repo.delete!(invitation)

    conn
    |> put_flash(:success, "You have rejected the invitation to #{invitation.site.domain}")
    |> redirect(to: "/sites")
  end
end
