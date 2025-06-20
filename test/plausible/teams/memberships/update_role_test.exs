defmodule Plausible.Teams.Memberships.UpdateRoleTest do
  use Plausible.DataCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test
  use Plausible

  alias Plausible.Teams.Memberships.UpdateRole

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

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
    assert_no_emails_delivered()
  end

  test "can demote self when an owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)
    _collaborator = add_member(team, role: :owner)

    assert {:ok, _} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :viewer)
    assert_no_emails_delivered()
  end

  test "can't demote self when the only owner" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)

    assert {:error, :only_one_owner} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :owner)
    assert_no_emails_delivered()
  end

  test "can demote self when an admin" do
    user = new_user()
    owner = new_user()
    _site = new_site(owner: owner)
    team = team_of(owner)
    _admin = add_member(team, user: user, role: :admin)

    assert {:ok, _} = UpdateRole.update(team, user.id, "viewer", user)

    assert_team_membership(user, team, :viewer)
    assert_no_emails_delivered()
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
    assert_no_emails_delivered()
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
      assert_no_emails_delivered()
    end
  end

  test "guest->member promotion sends out an e-mail" do
    user = new_user()
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    add_guest(site, role: :viewer, user: user)

    assert {:ok, _} = UpdateRole.update(team, user.id, "editor", owner)

    assert_email_delivered_with(
      to: [nil: user.email],
      subject: @subject_prefix <> "Welcome to \"#{team.name}\" team"
    )
  end

  on_ee do
    describe "SSO user" do
      setup [:create_user, :create_team, :setup_sso, :provision_sso_user]

      test "updates an SSO member's role by user id", %{team: team, user: user} do
        collaborator = add_member(team, role: :viewer)

        {:ok, _, _, collaborator} =
          new_identity(collaborator.name, collaborator.email)
          |> Plausible.Auth.SSO.provision_user()

        assert {:ok, _} = UpdateRole.update(team, collaborator.id, "editor", user)

        assert_team_membership(collaborator, team, :editor)
      end

      test "updates an SSO member's role to owner when no Force SSO set", %{
        team: team,
        user: user
      } do
        collaborator = add_member(team, role: :viewer)

        {:ok, _, _, collaborator} =
          new_identity(collaborator.name, collaborator.email)
          |> Plausible.Auth.SSO.provision_user()

        assert {:ok, _} = UpdateRole.update(team, collaborator.id, "owner", user)

        assert_team_membership(collaborator, team, :owner)
      end

      test "updates an SSO member's role with Force SSO to Owner provided they have 2FA enabled",
           %{
             team: team,
             user: user
           } do
        {:ok, user, _} = Plausible.Auth.TOTP.initiate(user)
        {:ok, user, _} = Plausible.Auth.TOTP.enable(user, :skip_verify)
        {:ok, team} = Plausible.Auth.SSO.set_force_sso(team, :all_but_owners)
        collaborator = add_member(team, role: :viewer)

        {:ok, _, _, collaborator} =
          new_identity(collaborator.name, collaborator.email)
          |> Plausible.Auth.SSO.provision_user()

        {:ok, collaborator, _} = Plausible.Auth.TOTP.initiate(collaborator)
        {:ok, collaborator, _} = Plausible.Auth.TOTP.enable(collaborator, :skip_verify)

        assert {:ok, _} = UpdateRole.update(team, collaborator.id, "owner", user)

        assert_team_membership(collaborator, team, :owner)
      end

      test "does not update SSO member's role to Owner if they don't have 2FA enabled", %{
        team: team,
        user: user
      } do
        {:ok, user, _} = Plausible.Auth.TOTP.initiate(user)
        {:ok, user, _} = Plausible.Auth.TOTP.enable(user, :skip_verify)
        {:ok, team} = Plausible.Auth.SSO.set_force_sso(team, :all_but_owners)
        collaborator = add_member(team, role: :viewer)

        {:ok, _, _, collaborator} =
          new_identity(collaborator.name, collaborator.email)
          |> Plausible.Auth.SSO.provision_user()

        assert {:error, :mfa_disabled} = UpdateRole.update(team, collaborator.id, "owner", user)
      end
    end
  end
end
