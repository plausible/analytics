defmodule PlausibleWeb.Site.InvitationControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  use Bamboo.Test
  import Plausible.TestUtils

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

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)
      assert membership.role == :admin
    end

    test "notifies the original inviter", %{conn: conn, user: user} do
      inviter = insert(:user)
      site = insert(:site)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject: "[Plausible Analytics] #{user.email} accepted your invitation to #{site.domain}"
      )
    end

    test "ownership transfer - downgrades previous owner to admin", %{conn: conn, user: user} do
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

  describe "DELETE /sites/invitations/:invitation_id" do
    test "removes the invitation", %{conn: conn} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: "jane@example.com",
          role: :admin
        )

      delete(conn, "/sites/invitations/#{invitation.invitation_id}")

      refute Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end
  end

  describe "GET /sites/:website/transfer-ownership" do
    test "shows the form", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      conn = get(conn, "/sites/#{site.domain}/transfer-ownership")

      assert html_response(conn, 200) =~ "Transfer ownership"
    end
  end
end
