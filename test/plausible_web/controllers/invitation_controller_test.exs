defmodule PlausibleWeb.Site.InvitationControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  alias Plausible.Teams

  setup [:create_user, :log_in]

  describe "POST /sites/invitations/:invitation_id/accept" do
    test "converts the invitation into a membership", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)

      invitation =
        invite_guest(site, user.email, inviter: owner, role: :editor)

      conn = post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "You now have access to #{site.domain}"

      assert redirected_to(conn) == "/#{URI.encode_www_form(site.domain)}"

      refute Repo.exists?(from(i in Plausible.Teams.Invitation, where: i.email == ^user.email))

      assert_guest_membership(site.team, site, user, :editor)
    end

    test "converts the team invitation into a team membership", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)

      invitation =
        invite_member(team, user.email, inviter: owner, role: :editor)

      conn = post(conn, "/settings/team/invitations/#{invitation.invitation_id}/accept")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "You now have access to \"#{team.name}\" team"

      assert redirected_to(conn) == "/sites"

      refute Repo.get_by(Teams.Invitation, email: user.email)

      assert_team_membership(user, team, :editor)
    end

    test "does not crash if clicked for the 2nd time in another tab", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)
      invitation = invite_guest(site, user.email, role: :editor, inviter: owner)

      c1 = post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")
      assert redirected_to(c1) == "/#{URI.encode_www_form(site.domain)}"

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
      old_owner = new_user()
      site = new_site(owner: old_owner)

      subscribe_to_growth_plan(user)
      new_team = team_of(user)

      transfer = invite_transfer(site, user, inviter: old_owner)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}"

      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~
               "You now have access to"

      refute Repo.reload(transfer)

      assert_guest_membership(new_team, site, old_owner, :editor)

      assert_team_attached(site, new_team.id)
    end

    test "fails when new owner has no permissions for current team", %{conn: conn, user: user} do
      old_owner = new_user()
      site = new_site(owner: old_owner)

      other_owner = new_user() |> subscribe_to_growth_plan()
      new_team = team_of(other_owner)
      add_member(new_team, user: user, role: :viewer)
      conn = set_current_team(conn, new_team)

      transfer = invite_transfer(site, user, inviter: old_owner)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == "/sites"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You can't add sites in the current team"
    end

    test "fails when transferring to the same team", %{conn: conn, user: user} do
      current_owner = user |> subscribe_to_growth_plan()
      site = new_site(owner: current_owner)

      transfer = invite_transfer(site, current_owner, inviter: current_owner)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == "/sites"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The site is already in the current team"
    end

    test "allows transferring between different teams of the same owner", %{
      conn: conn,
      user: user
    } do
      current_owner = user |> subscribe_to_growth_plan()
      site = new_site(owner: current_owner)

      another_owner = new_user() |> subscribe_to_growth_plan()
      new_team = team_of(another_owner)
      add_member(new_team, user: current_owner, role: :owner)

      transfer = invite_transfer(site, current_owner, inviter: current_owner)

      conn = set_current_team(conn, new_team)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}"

      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~
               "You now have access to"

      refute Repo.reload(transfer)

      assert_team_membership(current_owner, new_team, :owner)

      assert_team_attached(site, new_team.id)
    end

    @tag :ee_only
    test "fails when new owner has no plan", %{conn: conn, user: user} do
      old_owner = new_user()
      site = new_site(owner: old_owner)

      transfer = invite_transfer(site, user, inviter: old_owner)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "No existing subscription"
    end

    @tag :ee_only
    test "fails when new owner's plan is unsuitable", %{conn: conn, user: user} do
      old_owner = new_user()
      site = new_site(owner: old_owner)

      subscribe_to_growth_plan(user)

      # fill site limit quota
      for _ <- 1..10, do: new_site(owner: user)

      transfer = invite_transfer(site, user, inviter: old_owner)

      conn = post(conn, "/sites/invitations/#{transfer.transfer_id}/accept")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Plan limits exceeded: site limit."
    end
  end

  describe "POST /sites/invitations/:invitation_id/reject" do
    test "rejects the invitation", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)

      invitation = invite_guest(site, user.email, inviter: owner, role: :editor)

      conn = post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      assert redirected_to(conn, 302) == "/sites"

      refute Repo.reload(invitation)
    end

    test "rejects the team invitation", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)

      invitation = invite_member(team, user.email, inviter: owner, role: :editor)

      conn = post(conn, "/settings/team/invitations/#{invitation.invitation_id}/reject")

      assert redirected_to(conn, 302) == "/sites"

      refute Repo.reload(invitation)
    end

    test "renders error for non-existent invitation", %{conn: conn} do
      conn = post(conn, "/sites/invitations/does-not-exist/reject")

      assert redirected_to(conn, 302) == "/sites"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invitation missing or already accepted"
    end
  end

  describe "DELETE /sites/:domain/invitations/:invitation_id" do
    test "removes the invitation", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)
      add_guest(site, user: user, role: :editor)
      invitation = invite_guest(site, "jane@example.com", inviter: owner, role: :editor)

      conn =
        delete(
          conn,
          Routes.invitation_path(conn, :remove_invitation, site.domain, invitation.invitation_id)
        )

      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}/settings/people"

      refute Repo.reload(invitation)
    end

    test "removes the invitation for ownership transfer", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)
      add_guest(site, user: user, role: :editor)
      transfer = invite_transfer(site, "jane@example.com", inviter: owner)

      conn =
        delete(
          conn,
          Routes.invitation_path(conn, :remove_invitation, site.domain, transfer.transfer_id)
        )

      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}/settings/people"

      refute Repo.reload(transfer)
    end

    test "fails to remove an invitation with insufficient permission", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)
      add_guest(site, user: user, role: :viewer)

      invitation = invite_guest(site, "jane@example.com", inviter: owner, role: :editor)

      delete(
        conn,
        Routes.invitation_path(conn, :remove_invitation, site.domain, invitation.invitation_id)
      )

      assert Repo.reload(invitation)
    end

    test "fails to remove an invitation from the outside", %{conn: my_conn, user: me} do
      new_site(owner: me)

      other_user = new_user()

      other_site = new_site(owner: other_user)

      invitation =
        invite_guest(other_site, "jane@example.com", role: :editor, inviter: other_user)

      remove_invitation_path =
        Routes.invitation_path(
          my_conn,
          :remove_invitation,
          other_site.domain,
          invitation.invitation_id
        )

      delete(my_conn, remove_invitation_path)

      assert Repo.reload(invitation)
    end

    test "renders error for non-existent invitation", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      remove_invitation_path =
        Routes.invitation_path(
          conn,
          :remove_invitation,
          site.domain,
          "does_not_exist"
        )

      conn = delete(conn, remove_invitation_path)

      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}/settings/people"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invitation missing or already removed"
    end
  end

  describe "DELETE /team/invitations/:invitation_id" do
    for role <- [:owner, :admin], invitee_role <- Teams.Membership.roles() do
      test "#{role} removes the #{invitee_role} team invitation", %{conn: conn, user: user} do
        owner = new_user()
        _site = new_site(owner: owner)
        team = team_of(owner)
        add_member(team, user: user, role: unquote(role))
        conn = set_current_team(conn, team)

        invitation =
          invite_member(team, "jane@example.com", inviter: owner, role: unquote(invitee_role))

        conn =
          delete(
            conn,
            Routes.invitation_path(conn, :remove_team_invitation, invitation.invitation_id)
          )

        assert redirected_to(conn, 302) == "/settings/team/general"

        refute Repo.reload(invitation)
      end
    end

    for role <- Teams.Membership.roles() -- [:owner, :admin] do
      test "#{role} can't remove a team invitation", %{conn: conn, user: user} do
        owner = new_user()
        _site = new_site(owner: owner)
        team = team_of(owner)
        add_member(team, user: user, role: unquote(role))

        invitation =
          invite_member(team, "jane@example.com", inviter: owner, role: :viewer)

        conn =
          delete(
            conn,
            Routes.invitation_path(conn, :remove_team_invitation, invitation.invitation_id)
          )

        assert redirected_to(conn, 302) == "/settings/team/general"

        assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
                 "You are not allowed to remove invitations"

        assert Repo.reload(invitation)
      end
    end

    test "fails to remove a team invitation from the outside", %{conn: my_conn, user: me} do
      new_site(owner: me)
      other_user = new_user()
      _other_site = new_site(owner: other_user)
      other_team = team_of(other_user)

      invitation =
        invite_member(other_team, "jane@example.com", role: :editor, inviter: other_user)

      remove_invitation_path =
        Routes.invitation_path(
          my_conn,
          :remove_team_invitation,
          invitation.invitation_id
        )

      my_conn = delete(my_conn, remove_invitation_path)

      assert Phoenix.Flash.get(my_conn.assigns.flash, :error) ==
               "Invitation missing or already removed"

      assert Repo.reload(invitation)
    end

    test "renders error for non-existent team invitation", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      add_member(team, user: user, role: :editor)
      conn = set_current_team(conn, team)

      remove_invitation_path =
        Routes.invitation_path(
          conn,
          :remove_team_invitation,
          "does_not_exist"
        )

      conn = delete(conn, remove_invitation_path)

      assert redirected_to(conn, 302) == "/settings/team/general"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invitation missing or already removed"
    end
  end
end
