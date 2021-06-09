defmodule PlausibleWeb.Site.MembershipControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  use Bamboo.Test
  import Plausible.TestUtils

  setup [:create_user, :log_in]

  describe "GET /sites/:website/memberships/invite" do
    test "shows invite form", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      conn = get(conn, "/sites/#{site.domain}/memberships/invite")

      assert html_response(conn, 200) =~ "Invite member to"
    end
  end

  describe "POST /sites/:website/memberships/invite" do
    test "creates invitation", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "john.doe@example.com",
          role: "admin"
        })

      invitation = Repo.get_by(Plausible.Auth.Invitation, email: "john.doe@example.com")

      assert invitation.role == :admin
      assert redirected_to(conn) == "/#{site.domain}/settings/general"
    end

    test "sends invitation email", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      post(conn, "/sites/#{site.domain}/memberships/invite", %{
        email: "john.doe@example.com",
        role: "admin"
      })

      assert_email_delivered_with(
        to: [nil: "john.doe@example.com"],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )
    end
  end

  describe "PUT /sites/memberships/:id/role/:new_role" do
    test "updates a site member's role", %{conn: conn, user: user} do
      admin = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner),
            build(:site_membership, user: admin, role: :admin)
          ]
        )

      membership = Enum.find(site.memberships, &(&1.role == :admin))

      put(conn, "/sites/memberships/#{membership.id}/role/viewer")

      membership = Repo.get_by(Plausible.Site.Membership, user_id: admin.id)

      assert membership.role == :viewer
    end
  end

  describe "DELETE /sites/memberships/:id" do
    test "removes a member from a site", %{conn: conn, user: user} do
      admin = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner),
            build(:site_membership, user: admin, role: :admin)
          ]
        )

      membership = Enum.find(site.memberships, &(&1.role == :admin))

      delete(conn, "/sites/memberships/#{membership.id}")

      refute Repo.exists?(from sm in Plausible.Site.Membership, where: sm.user_id == ^admin.id)
    end
  end

  describe "POST /sites/invitations/:invitation_id/accept" do
    test "converts the invitation into a membership", %{conn: conn, user: user} do
      site = insert(:site)
      invitation = insert(:invitation, site_id: site.id, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)
      assert membership.role == :admin
    end
  end

  describe "POST /sites/invitations/:invitation_id/reject" do
    test "deletes the invitation", %{conn: conn, user: user} do
      site = insert(:site)
      invitation = insert(:invitation, site_id: site.id, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))
    end
  end

  describe "DELETE /sites/invitations/:invitation_id" do
    test "removes the invitation", %{conn: conn} do
      site = insert(:site)
      invitation = insert(:invitation, site_id: site.id, email: "jane@example.com", role: :admin)

      delete(conn, "/sites/invitations/#{invitation.invitation_id}")

      refute Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end
  end
end
