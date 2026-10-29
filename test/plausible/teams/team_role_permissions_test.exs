defmodule Plausible.Teams.TeamRolePermissionsTest do
  use Plausible.DataCase, async: true

  alias Plausible.Teams.TeamRolePermissions

  @roles Plausible.Teams.Membership.roles()
  @assignable_roles List.delete(@roles, :guest)

  @as %{
    owner: "an owner",
    admin: "an admin",
    editor: "an editor",
    viewer: "a viewer",
    billing: "a billing member",
    guest: "a guest"
  }

  describe "can_modify_member?/2" do
    for current_role <- @roles do
      test "as an owner, I can change the role of #{@as[current_role]}" do
        assert TeamRolePermissions.can_modify_member?(:owner, unquote(current_role))
      end
    end

    for current_role <- [:admin, :editor, :viewer] do
      test "as an admin, I can change the role of #{@as[current_role]}" do
        assert TeamRolePermissions.can_modify_member?(:admin, unquote(current_role))
      end
    end

    for current_role <- [:owner, :billing, :guest] do
      test "as an admin, I cannot change the role of #{@as[current_role]}" do
        refute TeamRolePermissions.can_modify_member?(:admin, unquote(current_role))
      end
    end

    for actor_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[actor_role]}, I cannot change anyone's role" do
        refute TeamRolePermissions.can_modify_member?(unquote(actor_role), :viewer)
      end
    end
  end

  describe "can_modify_invitation?/2" do
    for current_role <- @roles do
      test "as an owner, I can change the role of a pending #{current_role} invitation" do
        assert TeamRolePermissions.can_modify_invitation?(:owner, unquote(current_role))
      end
    end

    for current_role <- [:admin, :editor, :viewer, :billing] do
      test "as an admin, I can change the role of a pending #{current_role} invitation" do
        assert TeamRolePermissions.can_modify_invitation?(:admin, unquote(current_role))
      end
    end

    for current_role <- [:owner, :guest] do
      test "as an admin, I cannot change the role of a pending #{current_role} invitation" do
        refute TeamRolePermissions.can_modify_invitation?(:admin, unquote(current_role))
      end
    end

    for actor_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[actor_role]}, I cannot change invitations" do
        refute TeamRolePermissions.can_modify_invitation?(unquote(actor_role), :viewer)
      end
    end
  end

  describe "can_assign?/2" do
    for new_role <- @assignable_roles do
      test "as an owner, I can assign the #{new_role} role" do
        assert TeamRolePermissions.can_assign?(:owner, unquote(new_role))
      end
    end

    for new_role <- [:admin, :editor, :viewer, :billing] do
      test "as an admin, I can assign the #{new_role} role" do
        assert TeamRolePermissions.can_assign?(:admin, unquote(new_role))
      end
    end

    test "as an admin, I cannot assign the owner role" do
      refute TeamRolePermissions.can_assign?(:admin, :owner)
    end

    for actor_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[actor_role]}, I cannot assign any role" do
        refute TeamRolePermissions.can_assign?(unquote(actor_role), :viewer)
      end
    end

    for actor_role <- @roles do
      test "as #{@as[actor_role]}, I cannot assign the guest role" do
        assert_raise ArgumentError, "invalid role: :guest", fn ->
          TeamRolePermissions.can_assign?(unquote(actor_role), :guest)
        end
      end
    end

    test "as an owner, I cannot assign an invalid role" do
      assert_raise ArgumentError, "invalid role: :unknown", fn ->
        TeamRolePermissions.can_assign?(:owner, :unknown)
      end
    end

    test "as an owner, I cannot assign a role given as a string" do
      assert_raise ArgumentError, ~s(invalid role: "admin"), fn ->
        TeamRolePermissions.can_assign?(:owner, "admin")
      end
    end
  end

  describe "ensure_can_change_member_role/4" do
    setup [:create_user, :create_team]

    test "allows a change the actor's role permits", %{user: owner, team: team} do
      member = add_member(team, role: :viewer)
      membership = get_membership(team, member)

      assert :ok =
               TeamRolePermissions.ensure_can_change_member_role(
                 team,
                 owner,
                 membership,
                 :editor
               )
    end

    test "denies a change the actor's role doesn't permit", %{user: owner, team: team} do
      admin = add_member(team, role: :admin)
      membership = get_membership(team, owner)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_change_member_role(
                 team,
                 admin,
                 membership,
                 :viewer
               )
    end

    for invalid_role <- [:guest, :unknown, "admin"] do
      test "raises for an invalid role (#{inspect(invalid_role)})", %{
        user: owner,
        team: team
      } do
        member = add_member(team, role: :viewer)
        membership = get_membership(team, member)

        assert_raise ArgumentError, fn ->
          TeamRolePermissions.ensure_can_change_member_role(
            team,
            owner,
            membership,
            unquote(invalid_role)
          )
        end
      end
    end

    test "returns permission error when the actor is not a member of the team", %{team: team} do
      member = add_member(team, role: :viewer)
      membership = get_membership(team, member)
      outsider = new_user()

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_change_member_role(
                 team,
                 outsider,
                 membership,
                 :editor
               )
    end
  end

  describe "ensure_can_change_invitation_role/4" do
    setup [:create_user, :create_team]

    test "allows a change the actor's role permits", %{user: owner, team: team} do
      admin = add_member(team, role: :admin)
      invitation = invite_member(team, "invitee@example.com", role: :viewer, inviter: owner)

      assert :ok =
               TeamRolePermissions.ensure_can_change_invitation_role(
                 team,
                 admin,
                 invitation,
                 :editor
               )
    end

    test "takes the current role of the invitation into account", %{user: owner, team: team} do
      admin = add_member(team, role: :admin)
      invitation = invite_member(team, "invitee@example.com", role: :owner, inviter: owner)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_change_invitation_role(
                 team,
                 admin,
                 invitation,
                 :viewer
               )
    end

    test "denies a role the actor's role doesn't permit", %{user: owner, team: team} do
      admin = add_member(team, role: :admin)
      invitation = invite_member(team, "invitee@example.com", role: :viewer, inviter: owner)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_change_invitation_role(
                 team,
                 admin,
                 invitation,
                 :owner
               )
    end

    for invalid_role <- [:guest, :unknown, "admin"] do
      test "raises for an invalid role (#{inspect(invalid_role)})", %{
        user: owner,
        team: team
      } do
        invitation = invite_member(team, "invitee@example.com", role: :viewer, inviter: owner)

        assert_raise ArgumentError, fn ->
          TeamRolePermissions.ensure_can_change_invitation_role(
            team,
            owner,
            invitation,
            unquote(invalid_role)
          )
        end
      end
    end

    test "returns permission error when the actor is not a member of the team", %{
      user: owner,
      team: team
    } do
      invitation = invite_member(team, "invitee@example.com", role: :viewer, inviter: owner)
      outsider = new_user()

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_change_invitation_role(
                 team,
                 outsider,
                 invitation,
                 :editor
               )
    end
  end

  describe "ensure_can_invite/3" do
    setup [:create_user, :create_team]

    test "allows a role the actor's role permits", %{team: team} do
      admin = add_member(team, role: :admin)

      assert :ok = TeamRolePermissions.ensure_can_invite(team, admin, :editor)
    end

    test "denies a role the actor's role doesn't permit", %{team: team} do
      admin = add_member(team, role: :admin)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_invite(team, admin, :owner)
    end

    for actor_role <- [:editor, :viewer, :billing] do
      test "as #{@as[actor_role]}, I cannot invite anyone", %{team: team} do
        actor = add_member(team, role: unquote(actor_role))

        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_invite(team, actor, :viewer)
      end
    end

    for invalid_role <- [:guest, :unknown, "admin"] do
      test "raises for an invalid role (#{inspect(invalid_role)})", %{
        user: owner,
        team: team
      } do
        assert_raise ArgumentError, fn ->
          TeamRolePermissions.ensure_can_invite(team, owner, unquote(invalid_role))
        end
      end
    end

    test "returns permission error when the actor is not a member of the team", %{team: team} do
      outsider = new_user()

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_invite(team, outsider, :viewer)
    end
  end

  describe "can_manage_team?/1" do
    for role <- [:owner, :admin] do
      test "#{@as[role]} can manage the team" do
        assert TeamRolePermissions.can_manage_team?(unquote(role))
      end
    end

    for role <- [:editor, :viewer, :billing, :guest] do
      test "#{@as[role]} cannot manage the team" do
        refute TeamRolePermissions.can_manage_team?(unquote(role))
      end
    end
  end

  defp get_membership(team, user) do
    {:ok, membership} = Plausible.Teams.Memberships.get_team_membership(team, user.id)
    membership
  end
end
