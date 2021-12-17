defmodule PlausibleWeb.Site.MembershipController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Sites
  alias Plausible.Site.Membership
  alias Plausible.Auth.Invitation

  @only_owner_is_allowed_to [:transfer_ownership_form, :transfer_ownership]

  plug PlausibleWeb.RequireAccountPlug
  plug PlausibleWeb.AuthorizeSiteAccess, [:owner] when action in @only_owner_is_allowed_to

  plug PlausibleWeb.AuthorizeSiteAccess,
       [:owner, :admin] when action not in @only_owner_is_allowed_to

  def invite_member_form(conn, %{"website" => site_domain}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)

    render(
      conn,
      "invite_member_form.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"},
      skip_plausible_tracking: true
    )
  end

  def invite_member(conn, %{"website" => site_domain, "email" => email, "role" => role}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, site_domain)
    user = Plausible.Auth.find_user_by(email: email)

    if user && Sites.is_member?(user.id, site) do
      msg = "Cannot send invite because #{user.email} is already a member of #{site.domain}"

      render(conn, "invite_member_form.html",
        error: msg,
        site: site,
        layout: {PlausibleWeb.LayoutView, "focus.html"},
        skip_plausible_tracking: true
      )
    else
      invitation =
        Invitation.new(%{
          email: email,
          role: role,
          site_id: site.id,
          inviter_id: conn.assigns[:current_user].id
        })
        |> Repo.insert!()
        |> Repo.preload([:site, :inviter])

      email_template =
        if user do
          PlausibleWeb.Email.existing_user_invitation(invitation)
        else
          PlausibleWeb.Email.new_user_invitation(invitation)
        end

      Plausible.Mailer.send_email(email_template)

      conn
      |> put_flash(
        :success,
        "#{email} has been invited to #{site_domain} as #{PlausibleWeb.SiteView.with_indefinite_article(role)}"
      )
      |> redirect(to: Routes.site_path(conn, :settings_people, site.domain))
    end
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
    user = Plausible.Auth.find_user_by(email: email)

    invitation =
      Invitation.new(%{
        email: email,
        role: :owner,
        site_id: site.id,
        inviter_id: conn.assigns[:current_user].id
      })
      |> Repo.insert!()
      |> Repo.preload([:site, :inviter])

    PlausibleWeb.Email.ownership_transfer_request(invitation, user)
    |> Plausible.Mailer.send_email_safe()

    conn
    |> put_flash(:success, "Site transfer request has been sent to #{email}")
    |> redirect(to: Routes.site_path(conn, :settings_people, site.domain))
  end

  def update_role(conn, %{"id" => id, "new_role" => new_role}) do
    membership =
      Repo.get!(Membership, id)
      |> Repo.preload([:site, :user])
      |> Membership.changeset(%{role: new_role})
      |> Repo.update!()

    redirect_target =
      if membership.user.id == conn.assigns[:current_user].id && new_role == "viewer" do
        "/#{URI.encode_www_form(membership.site.domain)}"
      else
        Routes.site_path(conn, :settings_people, membership.site.domain)
      end

    conn
    |> put_flash(
      :success,
      "#{membership.user.name} is now #{PlausibleWeb.SiteView.with_indefinite_article(new_role)}"
    )
    |> redirect(to: redirect_target)
  end

  def remove_member(conn, %{"id" => id}) do
    membership =
      Repo.get!(Membership, id)
      |> Repo.preload([:user, :site])

    Repo.delete!(membership)

    PlausibleWeb.Email.site_member_removed(membership)
    |> Plausible.Mailer.send_email()

    redirect_target =
      if membership.user.id == conn.assigns[:current_user].id do
        "/#{URI.encode_www_form(membership.site.domain)}"
      else
        Routes.site_path(conn, :settings_people, membership.site.domain)
      end

    conn
    |> put_flash(
      :success,
      "#{membership.user.name} has been removed from #{membership.site.domain}"
    )
    |> redirect(to: redirect_target)
  end
end
