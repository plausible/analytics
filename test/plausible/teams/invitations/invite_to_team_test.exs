defmodule Plausible.Teams.Invitations.InviteToTeamTest do
  use Plausible.DataCase, async: true
  use Plausible
  use Bamboo.Test, shared: false
  use Plausible.Teams.Test

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Invitations.InviteToTeam

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "invite/4,5" do
    for role <- Teams.Invitation.roles() -- [:guest] do
      test "creates an invitation with role #{role} for existing user" do
        inviter = new_user()
        invitee = new_user()
        _site = new_site(owner: inviter)
        team = team_of(inviter)

        assert {:ok, %Plausible.Teams.Invitation{} = team_invitation} =
                 InviteToTeam.invite(team, inviter, invitee.email, unquote(role))

        assert team_invitation.team_id == team.id
        assert team_invitation.role == unquote(role)
        assert team_invitation.email == invitee.email
        assert team_invitation.inviter_id == inviter.id
        assert is_binary(team_invitation.invitation_id)
        assert [] = Repo.preload(team_invitation, :guest_invitations).guest_invitations

        assert_email_delivered_with(
          to: [nil: invitee.email],
          subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
        )
      end
    end

    for role <- Teams.Invitation.roles() -- [:guest] do
      test "creates an invitation with role #{role} for new user" do
        inviter = new_user()
        invitee = build(:user)
        _site = new_site(owner: inviter)
        team = team_of(inviter)

        assert {:ok, %Plausible.Teams.Invitation{} = team_invitation} =
                 InviteToTeam.invite(team, inviter, invitee.email, unquote(role))

        assert team_invitation.team_id == team.id
        assert team_invitation.role == unquote(role)
        assert team_invitation.email == invitee.email
        assert team_invitation.inviter_id == inviter.id
        assert is_binary(team_invitation.invitation_id)
        assert [] = Repo.preload(team_invitation, :guest_invitations).guest_invitations

        assert_email_delivered_with(
          to: [nil: invitee.email],
          subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team",
          html_body: ~r/#{team_invitation.invitation_id}/
        )
      end
    end

    for role <- Enum.map(Teams.Invitation.roles() -- [:guest], &to_string/1) do
      test "creates an invitation with role #{role} as a string" do
        inviter = new_user()
        invitee = new_user()
        _site = new_site(owner: inviter)
        team = team_of(inviter)

        assert {:ok, %Plausible.Teams.Invitation{} = team_invitation} =
                 InviteToTeam.invite(team, inviter, invitee.email, unquote(role))

        assert team_invitation.team_id == team.id
        assert team_invitation.role == unquote(String.to_existing_atom(role))
        assert team_invitation.email == invitee.email
        assert team_invitation.inviter_id == inviter.id
        assert is_binary(team_invitation.invitation_id)
        assert [] = Repo.preload(team_invitation, :guest_invitations).guest_invitations

        assert_email_delivered_with(
          to: [nil: invitee.email],
          subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
        )
      end
    end

    test "crashes on attempt to invite guest on a team level" do
      inviter = new_user()
      invitee = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert_raise RuntimeError, ~r/Invalid role passed/, fn ->
        InviteToTeam.invite(team, inviter, invitee.email, :guest)
      end

      assert_raise RuntimeError, ~r/Invalid role passed/, fn ->
        InviteToTeam.invite(team, inviter, invitee.email, "guest")
      end
    end

    test "overwrites existing invitation" do
      inviter = new_user()
      invitee = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)
      existing_invitation = invite_member(team, invitee.email, role: :viewer, inviter: inviter)

      assert {:ok, team_invitation} =
               InviteToTeam.invite(team, inviter, invitee.email, :editor)

      assert team_invitation.id == existing_invitation.id
      assert team_invitation.team_id == existing_invitation.team_id
      assert team_invitation.email == invitee.email
      assert team_invitation.role == :editor
    end

    test "overwrites existing guest invitation and prunes guest invitation entries" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      team = team_of(inviter)
      existing_invitation = invite_guest(site, invitee.email, role: :viewer, inviter: inviter)

      assert {:ok, team_invitation} =
               InviteToTeam.invite(team, inviter, invitee.email, :viewer)

      assert team_invitation.id == existing_invitation.team_invitation.id
      assert team_invitation.team_id == existing_invitation.team_invitation.team_id
      assert team_invitation.email == invitee.email
      assert team_invitation.role == :viewer
      assert [] = Repo.preload(team_invitation, :guest_invitations).guest_invitations
    end

    test "returns validation errors" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert {:error, changeset} = InviteToTeam.invite(team, inviter, "", :viewer)
      assert {"can't be blank", _} = changeset.errors[:email]
    end

    for role <- Teams.Invitation.roles() -- [:guest] do
      test "returns error when existing user is already a member (role #{role})" do
        inviter = new_user()
        invitee = new_user()
        _site = new_site(owner: inviter)
        team = team_of(inviter)
        add_member(team, user: invitee, role: unquote(role))

        assert {:error, :already_a_member} =
                 InviteToTeam.invite(team, inviter, invitee.email, :editor)
      end
    end

    test "succeeds when existing user is only a guest member" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      team = team_of(inviter)
      add_guest(site, user: invitee, role: :viewer)

      assert {:ok, _team_invitation} =
               InviteToTeam.invite(team, inviter, invitee.email, :viewer)
    end

    @tag :ee_only
    test "returns error when owner is over their team member limit" do
      [owner, inviter, invitee] = for _ <- 1..3, do: new_user()
      subscribe_to_growth_plan(owner)
      _site = new_site(owner: owner)
      team = team_of(owner)
      inviter = add_member(team, user: inviter, role: :admin)
      for _ <- 1..2, do: add_member(team, role: :viewer)

      assert {:error, {:over_limit, 3}} =
               InviteToTeam.invite(team, inviter, invitee.email, :viewer)
    end

    @tag :ee_only
    test "allows creating an ownership transfer even when at team member limit" do
      inviter = new_user()
      invitee = build(:user)
      _site = new_site(owner: inviter)
      team = team_of(inviter)
      for _ <- 1..3, do: add_member(team, role: :viewer)

      assert {:ok, _team_invitation} =
               InviteToTeam.invite(team, inviter, invitee.email, :owner)
    end

    for role <- Teams.Invitation.roles() -- [:guest, :owner] do
      test "allows admins to invite new members except owners (invite role: #{role})" do
        owner = new_user()
        inviter = new_user()
        invitee = build(:user)
        _site = new_site(owner: owner)
        team = team_of(owner)
        add_member(team, user: inviter, role: :admin)

        assert {:ok, _team_invitation} =
                 InviteToTeam.invite(team, inviter, invitee.email, unquote(role))
      end
    end

    for role <- Teams.Invitation.roles() -- [:owner] do
      test "only allows owners to invite new owners (inviter role: #{role})" do
        owner = new_user()
        inviter = new_user()
        invitee = build(:user)
        _site = new_site(owner: owner)
        team = team_of(owner)
        add_member(team, user: inviter, role: unquote(role))

        assert {:error, :permission_denied} =
                 InviteToTeam.invite(team, inviter, invitee.email, :owner)
      end
    end
  end
end
