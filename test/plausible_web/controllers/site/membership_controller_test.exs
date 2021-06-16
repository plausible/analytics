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
      assert redirected_to(conn) == "/#{site.domain}/settings/people"
    end

    test "sends invitation email for new user", %{conn: conn, user: user} do
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

    test "sends invitation email for existing user", %{conn: conn, user: user} do
      existing_user = insert(:user)
      site = insert(:site, members: [user])

      post(conn, "/sites/#{site.domain}/memberships/invite", %{
        email: existing_user.email,
        role: "admin"
      })

      assert_email_delivered_with(
        to: [nil: existing_user.email],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )
    end

    test "renders form with error if the invitee is already a member", %{conn: conn, user: user} do
      second_member = insert(:user)
      site = insert(:site, members: [user, second_member])

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: second_member.email,
          role: "admin"
        })

      assert html_response(conn, 200) =~
               "#{second_member.email} is already a member of #{site.domain}"
    end
  end

  describe "GET /sites/:website/transfer-ownership" do
    test "shows ownership transfer form", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      conn = get(conn, "/sites/#{site.domain}/transfer-ownership")

      assert html_response(conn, 200) =~ "Transfer ownership of"
    end
  end

  describe "POST /sites/:website/transfer-ownership" do
    test "creates invitation with :owner role", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      conn =
        post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: "john.doe@example.com"})

      invitation = Repo.get_by(Plausible.Auth.Invitation, email: "john.doe@example.com")

      assert invitation.role == :owner
      assert redirected_to(conn) == "/#{site.domain}/settings/people"
    end

    test "sends ownership transfer email for new user", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: "john.doe@example.com"})

      assert_email_delivered_with(
        to: [nil: "john.doe@example.com"],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site.domain}"
      )
    end

    test "sends invitation email for existing user", %{conn: conn, user: user} do
      existing_user = insert(:user)
      site = insert(:site, members: [user])

      post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: existing_user.email})

      assert_email_delivered_with(
        to: [nil: existing_user.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site.domain}"
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

      membership = Repo.get_by(Plausible.Site.Membership, user_id: admin.id)

      put(conn, "/sites/#{site.domain}/memberships/#{membership.id}/role/viewer")

      membership = Repo.reload!(membership)

      assert membership.role == :viewer
    end

    test "can downgrade yourself from admin to viewer, redirects to stats instead", %{
      conn: conn,
      user: user
    } do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id)

      conn = put(conn, "/sites/#{site.domain}/memberships/#{membership.id}/role/viewer")

      membership = Repo.reload!(membership)

      assert membership.role == :viewer
      assert redirected_to(conn) == "/#{site.domain}"
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

      delete(conn, "/sites/#{site.domain}/memberships/#{membership.id}")

      refute Repo.exists?(from sm in Plausible.Site.Membership, where: sm.user_id == ^admin.id)
    end

    test "notifies the user who has been removed via email", %{conn: conn, user: user} do
      admin = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner),
            build(:site_membership, user: admin, role: :admin)
          ]
        )

      membership = Enum.find(site.memberships, &(&1.role == :admin))

      delete(conn, "/sites/#{site.domain}/memberships/#{membership.id}")

      assert_email_delivered_with(
        to: [nil: admin.email],
        subject: "[Plausible Analytics] Your access to #{site.domain} has been revoked"
      )
    end
  end
end
