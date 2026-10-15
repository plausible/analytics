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

  describe "ensure_can_change_role/3" do
    test "raises for an unknown type" do
      assert_raise ArgumentError, "unknown type: :unknown", fn ->
        TeamRolePermissions.ensure_can_change_role(:unknown, :owner, :viewer)
      end
    end
  end

  describe "ensure_can_change_role/3 for members" do
    for current_role <- @roles do
      test "as an owner, I can change the role of #{@as[current_role]}" do
        assert :ok =
                 TeamRolePermissions.ensure_can_change_role(
                   :membership,
                   :owner,
                   unquote(current_role)
                 )
      end
    end

    for current_role <- [:admin, :editor, :viewer] do
      test "as an admin, I can change the role of #{@as[current_role]}" do
        assert :ok =
                 TeamRolePermissions.ensure_can_change_role(
                   :membership,
                   :admin,
                   unquote(current_role)
                 )
      end
    end

    for current_role <- [:owner, :billing, :guest] do
      test "as an admin, I cannot change the role of #{@as[current_role]}" do
        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_change_role(
                   :membership,
                   :admin,
                   unquote(current_role)
                 )
      end
    end

    for granter_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[granter_role]}, I cannot change anyone's role" do
        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_change_role(
                   :membership,
                   unquote(granter_role),
                   :viewer
                 )
      end
    end
  end

  describe "ensure_can_change_role/3 for invitations" do
    for granter_role <- [:owner, :admin] do
      test "as #{@as[granter_role]}, I can create an invitation" do
        assert :ok =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   unquote(granter_role),
                   nil
                 )
      end
    end

    for current_role <- @roles do
      test "as an owner, I can change the role of a pending #{current_role} invitation" do
        assert :ok =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   :owner,
                   unquote(current_role)
                 )
      end
    end

    for current_role <- [:admin, :editor, :viewer, :billing] do
      test "as an admin, I can change the role of a pending #{current_role} invitation" do
        assert :ok =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   :admin,
                   unquote(current_role)
                 )
      end
    end

    for current_role <- [:owner, :guest] do
      test "as an admin, I cannot change the role of a pending #{current_role} invitation" do
        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   :admin,
                   unquote(current_role)
                 )
      end
    end

    for granter_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[granter_role]}, I cannot create or change invitations" do
        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   unquote(granter_role),
                   nil
                 )

        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_change_role(
                   :invitation,
                   unquote(granter_role),
                   :viewer
                 )
      end
    end
  end

  describe "ensure_can_grant_role/2" do
    for to_role <- @assignable_roles do
      test "as an owner, I can grant the #{to_role} role" do
        assert :ok = TeamRolePermissions.ensure_can_grant_role(:owner, unquote(to_role))
      end
    end

    for to_role <- [:admin, :editor, :viewer, :billing] do
      test "as an admin, I can grant the #{to_role} role" do
        assert :ok = TeamRolePermissions.ensure_can_grant_role(:admin, unquote(to_role))
      end
    end

    test "as an admin, I cannot grant the owner role" do
      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_role(:admin, :owner)
    end

    for granter_role <- [:editor, :viewer, :billing, :guest] do
      test "as #{@as[granter_role]}, I cannot grant any role" do
        assert {:error, :permission_denied} =
                 TeamRolePermissions.ensure_can_grant_role(unquote(granter_role), :viewer)
      end
    end

    for granter_role <- @roles do
      test "as #{@as[granter_role]}, I cannot grant the guest role" do
        assert_raise ArgumentError, "invalid role: :guest", fn ->
          TeamRolePermissions.ensure_can_grant_role(unquote(granter_role), :guest)
        end
      end
    end

    test "as an owner, I cannot grant an invalid role" do
      assert_raise ArgumentError, "invalid role: :unknown", fn ->
        TeamRolePermissions.ensure_can_grant_role(:owner, :unknown)
      end
    end

    test "as an owner, I cannot grant a role given as a string" do
      assert_raise ArgumentError, ~s(invalid role: "admin"), fn ->
        TeamRolePermissions.ensure_can_grant_role(:owner, "admin")
      end
    end
  end

  describe "ensure_can_grant_for_member/4" do
    setup [:create_user, :create_team]

    test "allows a change the granter's role permits", %{user: owner, team: team} do
      member = add_member(team, role: :viewer)
      membership = get_membership(team, member)

      assert :ok =
               TeamRolePermissions.ensure_can_grant_for_member(team, owner, membership, :editor)
    end

    test "denies a change the granter's role doesn't permit", %{user: owner, team: team} do
      admin = add_member(team, role: :admin)
      membership = get_membership(team, owner)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_for_member(team, admin, membership, :viewer)
    end

    for invalid_role <- [:guest, :unknown, "admin"] do
      test "raises for an invalid role (#{inspect(invalid_role)})", %{
        user: owner,
        team: team
      } do
        member = add_member(team, role: :viewer)
        membership = get_membership(team, member)

        assert_raise ArgumentError, fn ->
          TeamRolePermissions.ensure_can_grant_for_member(
            team,
            owner,
            membership,
            unquote(invalid_role)
          )
        end
      end
    end

    test "returns permission error when the granter is not a member of the team", %{team: team} do
      member = add_member(team, role: :viewer)
      membership = get_membership(team, member)
      outsider = new_user()

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_for_member(
                 team,
                 outsider,
                 membership,
                 :editor
               )
    end
  end

  describe "ensure_can_grant_for_invitation/4" do
    setup [:create_user, :create_team]

    test "allows a role the granter's role permits", %{team: team} do
      admin = add_member(team, role: :admin)

      assert :ok = TeamRolePermissions.ensure_can_grant_for_invitation(team, admin, nil, :editor)
    end

    test "denies a role the granter's role doesn't permit", %{team: team} do
      admin = add_member(team, role: :admin)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_for_invitation(team, admin, nil, :owner)
    end

    test "takes the current role of a pending invitation into account", %{
      user: owner,
      team: team
    } do
      admin = add_member(team, role: :admin)
      invitation = invite_member(team, "invitee@example.com", role: :owner, inviter: owner)

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_for_invitation(
                 team,
                 admin,
                 invitation,
                 :viewer
               )
    end

    for invalid_role <- [:guest, :unknown, "admin"] do
      test "raises for an invalid role (#{inspect(invalid_role)})", %{
        user: owner,
        team: team
      } do
        assert_raise ArgumentError, fn ->
          TeamRolePermissions.ensure_can_grant_for_invitation(
            team,
            owner,
            nil,
            unquote(invalid_role)
          )
        end
      end
    end

    test "returns permission error when the granter is not a member of the team", %{team: team} do
      outsider = new_user()

      assert {:error, :permission_denied} =
               TeamRolePermissions.ensure_can_grant_for_invitation(team, outsider, nil, :viewer)
    end
  end

  defp get_membership(team, user) do
    {:ok, membership} = Plausible.Teams.Memberships.get_team_membership(team, user.id)
    membership
  end
end
