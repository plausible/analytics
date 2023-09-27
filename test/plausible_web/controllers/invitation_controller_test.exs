defmodule PlausibleWeb.Site.InvitationControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Bamboo.Test

  setup [:create_user, :log_in]

  describe "POST /sites/invitations/:invitation_id/accept" do
    test "converts the invitation into a membership", %{conn: conn, user: user} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :admin
        )

      conn = post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "You now have access to #{site.domain}"

      assert redirected_to(conn) == "/#{site.domain}"

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)
      assert membership.role == :admin
    end

    test "does not crash if clicked for the 2nd time in another tab", %{conn: conn, user: user} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :admin
        )

      c1 = post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")
      assert redirected_to(c1) == "/#{site.domain}"

      assert Phoenix.Flash.get(c1.assigns.flash, :success) ==
               "You now have access to #{site.domain}"

      c2 = post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")
      assert redirected_to(c2) == "/sites"

      assert Phoenix.Flash.get(c2.assigns.flash, :error) ==
               "Invitation missing or already accepted"
    end
  end

  describe "POST /sites/invitations/:invitation_id/accept - ownership transfer" do
    test "downgrades previous owner to admin", %{conn: conn, user: user} do
      old_owner = insert(:user)
      site = insert(:site, members: [old_owner])

      invitation =
        insert(:invitation, site_id: site.id, inviter: old_owner, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      old_owner_membership =
        Repo.get_by(Plausible.Site.Membership, user_id: old_owner.id, site_id: site.id)

      assert old_owner_membership.role == :admin

      new_owner_membership =
        Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)

      assert new_owner_membership.role == :owner
    end
  end

  describe "POST /sites/invitations/:invitation_id/reject" do
    test "deletes the invitation", %{conn: conn, user: user} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :admin
        )

      post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))
    end

    test "notifies the original inviter", %{conn: conn, user: user} do
      inviter = insert(:user)
      site = insert(:site)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject: "[Plausible Analytics] #{user.email} rejected your invitation to #{site.domain}"
      )
    end
  end

  describe "DELETE /sites/:website/invitations/:invitation_id" do
    test "removes the invitation", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: "jane@example.com",
          role: :admin
        )

      conn =
        delete(
          conn,
          Routes.invitation_path(conn, :remove_invitation, site.domain, invitation.invitation_id)
        )

      assert redirected_to(conn, 302) == "/#{site.domain}/settings/people"

      refute Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end

    test "fails to remove an invitation with insufficient permission", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: "jane@example.com",
          role: :admin
        )

      delete(
        conn,
        Routes.invitation_path(conn, :remove_invitation, site.domain, invitation.invitation_id)
      )

      assert Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end

    test "fails to remove an invitation from the outside", %{conn: my_conn, user: me} do
      my_site = insert(:site)
      insert(:site_membership, site: my_site, user: me, role: "owner")

      other_user = insert(:user)
      other_site = insert(:site)
      insert(:site_membership, site: other_site, user: other_user, role: "owner")

      invitation =
        insert(:invitation,
          site_id: other_site.id,
          inviter: other_user,
          email: "jane@example.com",
          role: :admin
        )

      remove_invitation_path =
        Routes.invitation_path(
          my_conn,
          :remove_invitation,
          other_site.domain,
          invitation.invitation_id
        )

      delete(my_conn, remove_invitation_path)

      assert Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end
  end
end
