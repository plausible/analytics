defmodule Plausible.Teams.Invitations.InviteToTeamTest do
  use Plausible.DataCase
  use Bamboo.Test

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Invitations.InviteToTeam

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "invite_all/3" do
    test "creates invitations with a role per entry, without sending e-mails" do
      inviter = new_user()
      invitee = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert {:ok, [editor_invitation, viewer_invitation]} =
               InviteToTeam.invite_all(team, inviter, [
                 %{email: invitee.email, role: :editor},
                 %{email: "new@example.com", role: :viewer}
               ])

      assert %Teams.Invitation{email: email, role: :editor} = editor_invitation
      assert email == invitee.email
      assert %Teams.Invitation{email: "new@example.com", role: :viewer} = viewer_invitation

      assert Repo.get_by(Teams.Invitation, team_id: team.id, email: invitee.email)
      assert Repo.get_by(Teams.Invitation, team_id: team.id, email: "new@example.com")

      assert_no_emails_delivered()
    end

    test "returns an error when inviting self as owner without creating any invitations" do
      me = new_user()
      _my_site = new_site(owner: me)
      team = team_of(me)

      assert {:error, :already_a_member} =
               InviteToTeam.invite_all(team, me, [%{email: me.email, role: :owner}])

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: me.email)
    end

    for email <- ["", "no-at-sign.example.com", "no-dot@example"] do
      test "returns an error for invalid email #{inspect(email)} without creating any invitations" do
        inviter = new_user()
        _site = new_site(owner: inviter)
        team = team_of(inviter)

        assert {:error, :invalid_email} =
                 InviteToTeam.invite_all(team, inviter, [
                   %{email: "first@example.com", role: :editor},
                   %{email: unquote(email), role: :admin}
                 ])

        refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "first@example.com")
      end
    end

    for role <- Teams.Invitation.roles() -- [:guest] do
      test "returns an error when inviting an existing member (role #{role})" do
        inviter = new_user()
        invitee = new_user()
        _site = new_site(owner: inviter)
        team = team_of(inviter)
        add_member(team, user: invitee, role: unquote(role))

        assert {:error, :already_a_member} =
                 InviteToTeam.invite_all(team, inviter, [%{email: invitee.email, role: :editor}])

        refute Repo.get_by(Teams.Invitation, team_id: team.id, email: invitee.email)
      end
    end

    test "returns an error when inviting a guest member" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      team = team_of(inviter)
      add_guest(site, user: invitee, role: :viewer)

      assert {:error, :already_a_guest} =
               InviteToTeam.invite_all(team, inviter, [%{email: invitee.email, role: :viewer}])

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: invitee.email)
    end

    test "returns an error when inviting an email with a pending guest invitation" do
      inviter = new_user()
      site = new_site(owner: inviter)
      team = team_of(inviter)
      invite_guest(site, "guest@example.com", role: :viewer, inviter: inviter)

      assert {:error, :invited_as_guest} =
               InviteToTeam.invite_all(team, inviter, [
                 %{email: "guest@example.com", role: :editor}
               ])

      assert %Teams.Invitation{role: :guest} =
               team_invitation =
               Repo.get_by(Teams.Invitation, team_id: team.id, email: "guest@example.com")

      assert [_] = Repo.preload(team_invitation, :guest_invitations).guest_invitations
    end

    test "returns an error for duplicate emails without creating any invitations" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert {:error, :duplicate_emails} =
               InviteToTeam.invite_all(team, inviter, [
                 %{email: "first@example.com", role: :viewer},
                 %{email: "first@example.com", role: :editor}
               ])

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "first@example.com")
    end

    test "returns an error when inviting an email with a pending team invitation" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      existing_invitation =
        invite_member(team, "invitee@example.com", role: :viewer, inviter: inviter)

      assert {:error, :invited_as_member} =
               InviteToTeam.invite_all(team, inviter, [
                 %{email: "Invitee@Example.com", role: :admin}
               ])

      invitation = Repo.reload!(existing_invitation)
      assert invitation.role == :viewer
      assert invitation.updated_at == existing_invitation.updated_at
      assert_no_emails_delivered()
    end

    test "treats emails differing only in case as duplicates" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert {:error, :duplicate_emails} =
               InviteToTeam.invite_all(team, inviter, [
                 %{email: "first@example.com", role: :viewer},
                 %{email: "First@Example.com", role: :editor}
               ])

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "first@example.com")
    end

    on_ee do
      test "counts invitations in the same call towards team member limit" do
        owner = new_user()
        subscribe_to_growth_plan(owner)
        _site = new_site(owner: owner)
        team = team_of(owner)
        add_member(team, role: :viewer)

        assert {:error, {:over_limit, 3}} =
                 InviteToTeam.invite_all(team, owner, [
                   %{email: "first@example.com", role: :viewer},
                   %{email: "second@example.com", role: :viewer},
                   %{email: "third@example.com", role: :viewer}
                 ])

        refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "first@example.com")
      end
    end

    test "raises for an invalid role" do
      inviter = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      assert_raise ArgumentError, "invalid role: :guest", fn ->
        InviteToTeam.invite_all(team, inviter, [%{email: "new@example.com", role: :guest}])
      end

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "new@example.com")
    end

    test "returns error when the inviter isn't allowed to give the role" do
      owner = new_user()
      _site = new_site(owner: owner)
      team = team_of(owner)
      admin = add_member(team, role: :admin)

      assert {:error, :permission_denied} =
               InviteToTeam.invite_all(team, admin, [%{email: "new@example.com", role: :owner}])

      refute Repo.get_by(Teams.Invitation, team_id: team.id, email: "new@example.com")
    end
  end

  describe "send_invitation_emails/1" do
    test "sends an e-mail per invitation, picking the template by invitee existence" do
      inviter = new_user()
      invitee = new_user()
      _site = new_site(owner: inviter)
      team = team_of(inviter)

      {:ok, invitations} =
        InviteToTeam.invite_all(team, inviter, [
          %{email: invitee.email, role: :editor},
          %{email: "new@example.com", role: :viewer}
        ])

      assert :ok = InviteToTeam.send_invitation_emails(invitations)

      subject = @subject_prefix <> "You've been invited to \"#{team.name}\" team"

      assert_email_delivered_with(
        to: [nil: invitee.email],
        subject: subject,
        html_body: ~r/#{PlausibleWeb.Endpoint.url()}\/sites"/
      )

      new_user_invitation = Enum.find(invitations, &(&1.email == "new@example.com"))

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: subject,
        html_body: ~r/\/register\/invitation\/#{new_user_invitation.invitation_id}/
      )
    end
  end
end
