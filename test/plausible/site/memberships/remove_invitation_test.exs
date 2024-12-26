defmodule Plausible.Site.Memberships.RemoveInvitationTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Site.Memberships.RemoveInvitation

  test "removes invitation" do
    inviter = new_user()
    invitee = new_user()
    site = new_site(owner: inviter)

    invitation =
      invite_guest(site, invitee, inviter: inviter, role: :editor)

    assert {:ok, removed_invitation} =
             RemoveInvitation.remove_invitation(invitation.invitation_id, site)

    assert removed_invitation.id == invitation.id
    refute Repo.reload(removed_invitation)
  end

  test "returns error for non-existent invitation" do
    site = new_site()

    assert {:error, :invitation_not_found} =
             RemoveInvitation.remove_invitation("does_not_exist", site)
  end

  test "does not allow removing invitation from another site" do
    inviter = new_user()
    invitee = new_user()
    site = new_site(owner: inviter)
    other_site = new_site(owner: inviter)
    invitation = invite_guest(site, invitee, role: :editor, inviter: inviter)

    assert {:error, :invitation_not_found} =
             RemoveInvitation.remove_invitation(invitation.invitation_id, other_site)

    assert Repo.reload(invitation)
  end
end
