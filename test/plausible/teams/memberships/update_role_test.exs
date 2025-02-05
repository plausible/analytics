defmodule Plausible.Teams.Memberships.UpdateRoleTest do
  use Plausible.DataCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  alias Plausible.Teams.Memberships.UpdateRole

  test "updates a team member's role by user id" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)
    collaborator = add_member(team, role: :editor)
    assert_team_membership(collaborator, team, :editor)

    assert {:ok, _} = UpdateRole.update(team, collaborator.id, "viewer", user)

    assert_team_membership(collaborator, team, :viewer)
  end

  test "owner can promote another member to owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)
    collaborator = add_member(team, role: :editor)
    assert_team_membership(collaborator, team, :editor)

    assert {:ok, _} = UpdateRole.update(team, collaborator.id, "owner", user)

    assert_team_membership(collaborator, team, :owner)
  end

  test "can demote self when an owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)
    _collaborator = add_member(team, role: :owner)

    assert {:ok, _} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :viewer)
  end

  test "can't demote self when the only owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)

    assert {:error, :only_one_owner} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :owner)
  end

  test "can demote self when an admin" do
    user = new_user()
    owner = new_user()
    _site = new_site(owner: owner)
    team = team_of(owner)
    _admin = add_member(team, user: user, role: :admin)

    assert {:ok, _} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :viewer)
  end

  test "admin can't update role of an owner" do
    user = new_user()
    owner = new_user()
    _site = new_site(owner: owner)
    team = team_of(owner)
    _admin = add_member(team, user: user, role: :admin)
    _another_owner = add_member(team, role: :owner)

    assert {:error, :permission_denied} = UpdateRole.update(team, owner.id, "viewer", user)

    assert_team_membership(owner, team, :owner)
  end

  for role <- Plausible.Teams.Membership.roles() -- [:owner, :admin] do
    test "#{role} can't update role of a member" do
      user = new_user()
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      _member = add_member(team, user: user, role: unquote(role))
      another_member = add_member(team, role: :viewer)

      assert {:error, :permission_denied} =
               UpdateRole.update(team, another_member.id, "editor", user)

      assert_team_membership(another_member, team, :viewer)
    end
  end
end
