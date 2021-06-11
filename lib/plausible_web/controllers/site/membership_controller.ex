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

    invitation =
      Invitation.new(%{
        email: email,
        role: role,
        site_id: site.id
      })
      |> Repo.insert!()

    if user do
      email_template =
        PlausibleWeb.Email.existing_user_invitation(
          email,
          conn.assigns[:current_user],
          site,
          invitation
        )

      Plausible.Mailer.send_email(email_template)
    else
      email_template =
        PlausibleWeb.Email.new_user_invitation(
          email,
          conn.assigns[:current_user],
          site,
          invitation
        )

      Plausible.Mailer.send_email(email_template)
    end

    conn
    |> put_flash(:success, "#{email} has been invited to #{site_domain} as a #{role}")
    |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
  end

  def transfer_ownership_form(conn, %{"website" => site_domain}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)

    render(
      conn,
      "transfer_ownership_form.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def transfer_ownership(conn, %{"website" => site_domain, "email" => email}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)

    Invitation.new(%{
      email: email,
      role: :owner,
      site_id: site.id
    })
    |> Repo.insert!()

    conn
    |> put_flash(:success, "Site transfer request has been sent to #{email}")
    |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
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

  def remove_member(conn, %{"id" => id}) do
    membership =
      Repo.get!(Membership, id)
      |> Repo.preload([:user, :site])

    Repo.delete!(membership)

    conn
    |> put_flash(
      :success,
      "#{membership.user.name} has been removed from #{membership.site.domain}"
    )
    |> redirect(to: "/#{URI.encode_www_form(membership.site.domain)}/settings/general")
  end

  def accept_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload(:site)

    user = conn.assigns[:current_user]
    existing_membership = Repo.get_by(Membership, user_id: user.id, site_id: invitation.site.id)

    multi =
      if invitation.role == :owner do
        downgrade_previous_owner(Multi.new(), invitation.site)
      else
        Multi.new()
      end

    membership_changeset =
      Membership.changeset(existing_membership || %Membership{}, %{
        user_id: user.id,
        site_id: invitation.site.id,
        role: invitation.role
      })

    multi =
      multi
      |> Multi.insert_or_update(:membership, membership_changeset)
      |> Multi.delete(:invitation, invitation)

    case Repo.transaction(multi) do
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

  defp downgrade_previous_owner(multi, site) do
    prev_owner =
      from(
        sm in Plausible.Site.Membership,
        where: sm.site_id == ^site.id,
        where: sm.role == :owner
      )

    Multi.update_all(multi, :prev_owner, prev_owner, set: [role: :admin])
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

  def remove_invitation(conn, %{"invitation_id" => invitation_id}) do
    invitation =
      Repo.get_by!(Invitation, invitation_id: invitation_id)
      |> Repo.preload(:site)

    Repo.delete!(invitation)

    conn
    |> put_flash(:success, "You have removed the invitation for #{invitation.email}")
    |> redirect(to: Routes.site_path(conn, :settings_general, invitation.site.domain))
  end
end
