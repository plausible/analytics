defmodule Plausible.Teams.Invitations.UpdateRoleTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  alias Plausible.Teams
  alias Plausible.Teams.Invitations.UpdateRole

  describe "update/4" do
    setup [:create_user, :create_team]

    test "changes the role of a pending team invitation without sending an e-mail", %{
      user: owner,
      team: team
    } do
      invitation = invite_member(team, "invitee@example.com", role: :viewer, inviter: owner)

      assert {:ok, %Teams.Invitation{role: :editor}} =
               UpdateRole.update(team, invitation.invitation_id, :editor, owner)

      updated = Repo.reload!(invitation)
      assert updated.role == :editor
      assert updated.inserted_at == invitation.inserted_at
      assert_no_emails_delivered()
    end

    test "returns error for a guest invitation and leaves it unchanged", %{
      user: owner,
      team: team
    } do
      site = new_site(team: team)
      guest_invitation = invite_guest(site, "guest@example.com", role: :viewer, inviter: owner)
      team_invitation = guest_invitation.team_invitation

      assert {:error, :guest_invitation} =
               UpdateRole.update(team, team_invitation.invitation_id, :editor, owner)

      team_invitation = team_invitation |> Repo.reload!() |> Repo.preload(:guest_invitations)
      assert team_invitation.role == :guest
      assert [_] = team_invitation.guest_invitations
    end

    test "returns error when the invitation belongs to another team", %{user: owner, team: team} do
      other_owner = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other_owner)

      invitation =
        invite_member(other_team, "invitee@example.com", role: :viewer, inviter: other_owner)

      assert {:error, :invitation_not_found} =
               UpdateRole.update(team, invitation.invitation_id, :editor, owner)
    end

    test "returns error when there is no team", %{user: owner} do
      assert {:error, :permission_denied} = UpdateRole.update(nil, "some-id", :editor, owner)
    end

    test "returns error when the granter isn't allowed to make the change", %{
      user: owner,
      team: team
    } do
      admin = add_member(team, role: :admin)
      invitation = invite_member(team, "invitee@example.com", role: :owner, inviter: owner)

      assert {:error, :permission_denied} =
               UpdateRole.update(team, invitation.invitation_id, :viewer, admin)

      assert Repo.reload!(invitation).role == :owner
    end
  end
end
