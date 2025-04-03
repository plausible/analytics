defmodule PlausibleWeb.Site.MembershipControllerTest do
  use Plausible
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  use Bamboo.Test

  use Plausible.Teams.Test
  import Plausible.Teams.Test
  import Plausible.Test.Support.HTML

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  setup [:create_user, :log_in]

  describe "GET /sites/:domain/memberships/invite" do
    test "shows invite form", %{conn: conn, user: user} do
      site = new_site(owner: user)

      html =
        conn
        |> get("/sites/#{site.domain}/memberships/invite")
        |> html_response(200)

      assert html =~ "Invite guest to"
      assert element_exists?(html, ~s/button[type=submit]/)
      refute element_exists?(html, ~s/button[type=submit][disabled]/)
    end

    @tag :ee_only
    test "display a notice when is over limit", %{conn: conn, user: user} do
      site = new_site(owner: user)

      for _ <- 1..5 do
        add_guest(site, role: :viewer)
      end

      html =
        conn
        |> get("/sites/#{site.domain}/memberships/invite")
        |> html_response(200)

      assert html =~ "Your account is limited to 3 team members"
    end
  end

  describe "POST /sites/:domain/memberships/invite" do
    test "creates invitation", %{conn: conn, user: user} do
      site = new_site(owner: user)

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "john.doe@example.com",
          role: "editor"
        })

      assert_guest_invitation(site.team, site, "john.doe@example.com", :editor)

      assert redirected_to(conn) == "/#{URI.encode_www_form(site.domain)}/settings/people"
    end

    @tag :ee_only
    test "fails to create invitation when is over limit", %{conn: conn, user: user} do
      site = new_site(owner: user)

      for _ <- 1..5 do
        add_guest(site, role: :viewer)
      end

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "john.doe@example.com",
          role: "editor"
        })

      assert html_response(conn, 200) =~
               "Your account is limited to 3 team members. You can upgrade your plan to increase this limit."
    end

    test "fails to create invitation with insufficient permissions", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "john.doe@example.com",
          role: "editor"
        })

      assert conn.status == 404
    end

    test "fails to create invitation if site transfer already exists", %{conn: conn, user: user} do
      site = new_site(owner: user)

      new_owner = new_user()

      post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: new_owner.email})
      assert_site_transfer(site, new_owner.email)

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: new_owner.email,
          role: "editor"
        })

      conn = get(recycle(conn), redirected_to(conn, 302))
      html = html_response(conn, 200)
      assert html =~ "Error"
      assert html =~ "This invitation has been already sent"
    end

    test "fails to create invitation for a foreign site", %{conn: my_conn, user: me} do
      _my_site = new_site(owner: me)

      other_user = new_user()

      other_site = new_site(owner: other_user)

      my_conn =
        post(my_conn, "/sites/#{other_site.domain}/memberships/invite", %{
          email: "john.doe@example.com",
          role: "editor"
        })

      assert my_conn.status == 404

      refute Repo.get_by(Plausible.Teams.Invitation, email: "john.doe@example.com")
    end

    test "sends invitation email for new user", %{conn: conn, user: user} do
      site = new_site(owner: user)

      post(conn, "/sites/#{site.domain}/memberships/invite", %{
        email: "john.doe@example.com",
        role: "editor"
      })

      assert_email_delivered_with(
        to: [nil: "john.doe@example.com"],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    test "sends invitation email for existing user", %{conn: conn, user: user} do
      existing_user = new_user()
      site = new_site(owner: user)

      post(conn, "/sites/#{site.domain}/memberships/invite", %{
        email: existing_user.email,
        role: "editor"
      })

      assert_email_delivered_with(
        to: [nil: existing_user.email],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    test "renders form with error if the invitee is already a member", %{conn: conn, user: user} do
      site = new_site(owner: user)

      second_member = new_user()
      add_guest(site, user: second_member, role: :viewer)

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: second_member.email,
          role: "editor"
        })

      assert html_response(conn, 200) =~
               "#{second_member.email} is already a member of #{site.domain}"
    end

    test "handles repeat invitation gracefully", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)

      _req1 =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "joe@example.com",
          role: "editor"
        })

      assert_email_delivered_with(
        to: [nil: "joe@example.com"],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )

      req2 =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: "joe@example.com",
          role: "editor"
        })

      assert_email_delivered_with(
        to: [nil: "joe@example.com"],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )

      assert Phoenix.Flash.get(req2.assigns.flash, :success) =~
               "has been invited to"
    end
  end

  describe "GET /sites/:domain/transfer-ownership" do
    test "shows ownership transfer form", %{conn: conn, user: user} do
      site = new_site(owner: user)

      conn = get(conn, "/sites/#{site.domain}/transfer-ownership")

      assert html_response(conn, 200) =~ "Transfer ownership of"
    end
  end

  describe "POST /sites/:domain/transfer-ownership" do
    test "creates invitation with :owner role", %{conn: conn, user: user} do
      site = new_site(owner: user)

      conn =
        post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: "john.doe@example.com"})

      assert_site_transfer(site, "john.doe@example.com")

      assert redirected_to(conn) == "/#{URI.encode_www_form(site.domain)}/settings/people"
    end

    test "sends ownership transfer email for new user", %{conn: conn, user: user} do
      site = new_site(owner: user)

      post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: "john.doe@example.com"})

      assert_email_delivered_with(
        to: [nil: "john.doe@example.com"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "sends invitation email for existing user", %{conn: conn, user: user} do
      existing_user = insert(:user)
      site = new_site(owner: user)

      post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: existing_user.email})

      assert_email_delivered_with(
        to: [nil: existing_user.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "fails to transfer ownership to a foreign domain", %{conn: conn, user: user} do
      new_site(owner: user)
      foreign_site = new_site()

      conn =
        post(conn, "/sites/#{foreign_site.domain}/transfer-ownership", %{
          email: "john.doe@example.com"
        })

      assert conn.status == 404
    end

    test "fails to transfer ownership to invited user with proper error message", ctx do
      %{conn: conn, user: user} = ctx
      site = new_site(owner: user)
      invited = "john.doe@example.com"

      # invite a user but don't join

      conn =
        post(conn, "/sites/#{site.domain}/memberships/invite", %{
          email: invited,
          role: "editor"
        })

      conn = get(recycle(conn), redirected_to(conn, 302))

      assert html_response(conn, 200) =~
               "#{invited} has been invited to #{site.domain} as an editor"

      # transferring ownership to that domain now fails

      conn = post(conn, "/sites/#{site.domain}/transfer-ownership", %{email: invited})
      conn = get(recycle(conn), redirected_to(conn, 302))
      html = html_response(conn, 200)
      assert html =~ "Transfer error"
      assert html =~ "Invitation has already been sent"
    end
  end

  describe "PUT /sites/memberships/:id/role/:new_role" do
    test "updates a site member's role by user id", %{conn: conn, user: user} do
      site = new_site(owner: user)
      collaborator = add_guest(site, role: :editor)
      assert_guest_membership(site.team, site, collaborator, :editor)

      put(conn, "/sites/#{site.domain}/memberships/u/#{collaborator.id}/role/viewer")

      assert_guest_membership(site.team, site, collaborator, :viewer)
    end

    test "team admin can update a site member's role by user id (from editor to viewer)", %{
      conn: conn,
      user: user
    } do
      site = new_site()
      team = Plausible.Teams.complete_setup(site.team)
      add_member(team, user: user, role: :admin)
      collaborator = add_guest(site, role: :editor)
      assert_guest_membership(team, site, collaborator, :editor)

      conn = set_current_team(conn, team)

      put(conn, "/sites/#{site.domain}/memberships/u/#{collaborator.id}/role/viewer")

      assert_guest_membership(team, site, collaborator, :viewer)
    end

    test "team admin can update a site member's role by user id (from viewer to editor)", %{
      conn: conn,
      user: user
    } do
      site = new_site()
      team = Plausible.Teams.complete_setup(site.team)
      add_member(team, user: user, role: :admin)
      collaborator = add_guest(site, role: :viewer)
      assert_guest_membership(team, site, collaborator, :viewer)

      conn = set_current_team(conn, team)

      put(conn, "/sites/#{site.domain}/memberships/u/#{collaborator.id}/role/editor")

      assert_guest_membership(team, site, collaborator, :editor)
    end

    test "team editor can't update site member's role", %{conn: conn, user: user} do
      site = new_site()
      team = Plausible.Teams.complete_setup(site.team)
      add_member(team, user: user, role: :editor)
      collaborator = add_guest(site, role: :editor)
      assert_guest_membership(team, site, collaborator, :editor)

      conn = set_current_team(conn, team)

      conn = put(conn, "/sites/#{site.domain}/memberships/u/#{collaborator.id}/role/viewer")

      assert html_response(conn, 404)

      assert_guest_membership(team, site, collaborator, :editor)
    end

    test "can't update role when an editor", %{
      conn: conn,
      user: user
    } do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      conn = put(conn, "/sites/#{site.domain}/memberships/u/#{user.id}/role/viewer")

      assert_guest_membership(site.team, site, user, :editor)

      assert html_response(conn, 404)
    end

    test "can't update role when a viewer", %{
      conn: conn,
      user: user
    } do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      another_guest = add_guest(site, role: :editor)

      conn = put(conn, "/sites/#{site.domain}/memberships/u/#{another_guest.id}/role/viewer")

      assert_guest_membership(site.team, site, another_guest, :editor)

      assert html_response(conn, 404)
    end

    test "owner cannot make anyone else owner", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      editor = new_user()
      add_guest(site, user: editor, role: :editor)

      conn = put(conn, "/sites/#{site.domain}/memberships/u/#{editor.id}/role/owner")

      assert_guest_membership(site.team, site, editor, :editor)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not allowed to grant the owner role"
    end

    test "owner cannot downgrade themselves", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)

      conn = put(conn, "/sites/#{site.domain}/memberships/u/#{user.id}/role/admin")

      membership = Repo.get_by(Plausible.Teams.Membership, user_id: user.id)

      assert membership.role == :owner

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not allowed to grant the admin role"
    end
  end

  describe "DELETE /sites/:domain/memberships/:id" do
    test "removes a member from a site by user id", %{conn: conn, user: user} do
      site = new_site(owner: user)
      admin = add_guest(site, role: :editor)

      conn = delete(conn, "/sites/#{site.domain}/memberships/u/#{admin.id}")
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "has been removed"

      refute Repo.exists?(from tm in Plausible.Teams.Membership, where: tm.user_id == ^admin.id)
    end

    test "when members is removed, associated personal segment is deleted", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      admin = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          type: :personal,
          owner: admin,
          site: site,
          name: "personal segment"
        )

      delete(conn, "/sites/#{site.domain}/memberships/u/#{admin.id}")

      refute Repo.reload(segment)
    end

    test "when members is removed, associated site segment will be owner-less", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      admin = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          type: :site,
          owner: admin,
          site: site,
          name: "site segment"
        )

      delete(conn, "/sites/#{site.domain}/memberships/u/#{admin.id}")

      assert Repo.reload(segment).owner_id == nil
    end

    test "fails to remove a member from a foreign site (silently)", %{conn: conn, user: user} do
      foreign_member = new_user()
      foreign_site = new_site()
      add_guest(foreign_site, user: foreign_member, role: :editor)

      site = new_site(owner: user)

      conn = delete(conn, "/sites/#{site.domain}/memberships/u/#{foreign_member.id}")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "has been removed"

      assert_guest_membership(foreign_site.team, foreign_site, foreign_member, :editor)
    end

    test "notifies the user who has been removed via email", %{conn: conn, user: user} do
      site = new_site(owner: user)
      editor = add_guest(site, role: :editor)

      delete(conn, "/sites/#{site.domain}/memberships/u/#{editor.id}")

      assert_email_delivered_with(
        to: [nil: editor.email],
        subject: @subject_prefix <> "Your access to #{site.domain} has been revoked"
      )
    end
  end
end
