defmodule PlausibleWeb.Site.MembershipController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Sites
  alias Plausible.Site.Membership
  alias Plausible.Auth.Invitation

  @only_owner_is_allowed_to [:transfer_ownership_form, :transfer_ownership]

  plug PlausibleWeb.RequireAccountPlug
  plug PlausibleWeb.AuthorizeStatsPlug, [:owner] when action in @only_owner_is_allowed_to

  plug PlausibleWeb.AuthorizeStatsPlug,
       [:owner, :admin] when action not in @only_owner_is_allowed_to

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
        site_id: site.id,
        inviter_id: conn.assigns[:current_user].id
      })
      |> Repo.insert!()
      |> Repo.preload([:site, :inviter])

    if user do
      email_template = PlausibleWeb.Email.existing_user_invitation(invitation)

      Plausible.Mailer.send_email(email_template)
    else
      email_template = PlausibleWeb.Email.new_user_invitation(invitation)

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
end
