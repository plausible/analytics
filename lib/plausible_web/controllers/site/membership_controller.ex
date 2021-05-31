defmodule PlausibleWeb.Site.MembershipController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Sites
  alias Plausible.Site.Membership

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
      Membership.changeset(%Membership{}, %{site_id: site.id, user_id: user.id, role: role})
      |> Repo.insert!()

      conn
      |> put_flash(:success, "#{email} now has access to the site as a #{role}")
      |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    else
      render(
        conn,
        "invite_member_form.html",
        site: site,
        error: "User does not exist",
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
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
end
