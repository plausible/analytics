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

    test "redirects with an error flash when the invitation already exists", %{
      conn: conn,
      user: user
    } do
      site = insert(:site, members: [user])

      _req1 =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "joe@example.com",
          role: "admin"
        })

      assert_email_delivered_with(
        to: [nil: "joe@example.com"],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )

      req2 =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "joe@example.com",
          role: "admin"
        })

      refute_email_delivered_with(
        to: [nil: "joe@example.com"],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )

      assert people_settings = redirected_to(req2, 302)

      assert ^people_settings =
               PlausibleWeb.Router.Helpers.site_path(
                 PlausibleWeb.Endpoint,
                 :settings_people,
                 site.domain
               )

      assert get_flash(req2, :error) =~ "This invitation has been already sent."
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

    test "owner cannot make anyone else owner", %{
      conn: conn,
      user: user
    } do
      admin = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner),
            build(:site_membership, user: admin, role: :admin)
          ]
        )

      membership = Repo.get_by(Plausible.Site.Membership, user_id: admin.id)

      conn = put(conn, "/sites/#{site.domain}/memberships/#{membership.id}/role/owner")

      membership = Repo.reload!(membership)

      assert membership.role == :admin
      assert get_flash(conn, :error) == "You are not allowed to grant the owner role"
    end

    test "owner cannot downgrade themselves", %{
      conn: conn,
      user: user
    } do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :owner)])

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id)

      conn = put(conn, "/sites/#{site.domain}/memberships/#{membership.id}/role/admin")

      membership = Repo.reload!(membership)

      assert membership.role == :owner
      assert get_flash(conn, :error) == "You are not allowed to grant the admin role"
    end

    test "admin can make another user admin", %{
      conn: conn,
      user: user
    } do
      viewer = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :admin),
            build(:site_membership, user: viewer, role: :viewer)
          ]
        )

      viewer_membership = Repo.get_by(Plausible.Site.Membership, user_id: viewer.id)

      conn = put(conn, "/sites/#{site.domain}/memberships/#{viewer_membership.id}/role/admin")

      viewer_membership = Repo.reload!(viewer_membership)

      assert viewer_membership.role == :admin
      assert redirected_to(conn) == "/#{site.domain}/settings/people"
    end

    test "admin can't make themselves an owner", %{conn: conn, user: user} do
      owner = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: owner, role: :owner),
            build(:site_membership, user: user, role: :admin)
          ]
        )

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id)

      conn = put(conn, "/sites/#{site.domain}/memberships/#{membership.id}/role/owner")

      membership = Repo.reload!(membership)

      assert membership.role == :admin
      assert get_flash(conn, :error) == "You are not allowed to grant the owner role"
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
