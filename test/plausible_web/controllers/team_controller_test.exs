defmodule PlausibleWeb.TeamControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  alias Plausible.Teams

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  setup [:create_user, :log_in]

  describe "PUT /team/memberships/u/:id/role/:new_role" do
    test "updates a team member's role by user id", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)
      collaborator = add_member(team, role: :editor)
      assert_team_membership(collaborator, team, :editor)

      put(conn, "/settings/team/memberships/u/#{collaborator.id}/role/viewer")

      assert_team_membership(collaborator, team, :viewer)
    end

    test "can demote self when an owner", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)
      _collaborator = add_member(team, role: :owner)

      conn = put(conn, "/settings/team/memberships/u/#{user.id}/role/viewer")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert_team_membership(user, team, :viewer)
    end

    test "can't demote self when the only owner", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)

      conn = put(conn, "/settings/team/memberships/u/#{user.id}/role/viewer")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "User is the only owner and can't be changed"

      assert_team_membership(user, team, :owner)
    end

    test "can demote self when an admin", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      _admin = add_member(team, user: user, role: :admin)

      conn = put(conn, "/settings/team/memberships/u/#{user.id}/role/viewer")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert_team_membership(user, team, :viewer)
    end

    test "admin can't update role of an owner", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      _admin = add_member(team, user: user, role: :admin)
      _another_owner = add_member(team, role: :owner)

      conn = put(conn, "/settings/team/memberships/u/#{owner.id}/role/viewer")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not allowed to grant role to that member"

      assert_team_membership(owner, team, :owner)
    end

    for role <- Teams.Membership.roles() -- [:owner, :admin, :guest] do
      test "#{role} can't update role of a member", %{conn: conn, user: user} do
        owner = new_user()
        _site = new_site(owner: owner)
        team = team_of(owner)
        _member = add_member(team, user: user, role: unquote(role))
        another_member = add_member(team, role: :viewer)

        conn = put(conn, "/settings/team/memberships/u/#{another_member.id}/role/editor")

        assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

        assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
                 "You are not allowed to grant role to that member"

        assert_team_membership(another_member, team, :viewer)
      end
    end
  end

  describe "DELETE /team/memberships/u/:id" do
    test "removes a member from a team", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)
      collaborator = add_member(team, role: :editor)
      assert_team_membership(collaborator, team, :editor)

      conn = delete(conn, "/settings/team/memberships/u/#{collaborator.id}")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "User has been removed from the team"

      refute_team_member(collaborator, team)

      assert_email_delivered_with(
        to: [nil: collaborator.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )
    end

    test "can't remove the only owner", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)

      conn = delete(conn, "/settings/team/memberships/u/#{user.id}")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "User is the only owner and can't be changed"

      assert_team_membership(user, team, :owner)
    end

    test "can remove self (the owner) when there's more than one owner", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)
      _another_owner = add_member(team, role: :owner)

      conn = delete(conn, "/settings/team/memberships/u/#{user.id}")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "User has been removed from the team"

      refute_team_member(user, team)
    end

    test "can remove another owner when there's more than one owner", %{conn: conn, user: user} do
      _site = new_site(owner: user)
      team = team_of(user)
      another_owner = add_member(team, role: :owner)

      conn = delete(conn, "/settings/team/memberships/u/#{another_owner.id}")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "User has been removed from the team"

      refute_team_member(another_owner, team)
    end

    test "admin can't remove owner", %{conn: conn, user: user} do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      _another_owner = add_member(team, role: :owner)
      _admin = add_member(team, user: user, role: :admin)

      conn = delete(conn, "/settings/team/memberships/u/#{owner.id}")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :team_general)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not allowed to remove that member"

      assert_team_membership(owner, team, :owner)
    end
  end
end
