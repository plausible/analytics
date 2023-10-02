defmodule Plausible.Site.Memberships.RemoveInvitationTest do
  use Plausible.DataCase, async: true

  alias Plausible.Site.Memberships.RemoveInvitation

  test "removes invitation" do
    inviter = insert(:user)
    invitee = insert(:user)
    site = insert(:site, members: [inviter])

    invitation =
      insert(:invitation,
        site_id: site.id,
        inviter: inviter,
        email: invitee.email,
        role: :admin
      )

    assert {:ok, removed_invitation} =
             RemoveInvitation.remove_invitation(invitation.invitation_id, site)

    assert removed_invitation.id == invitation.id
    refute Repo.reload(removed_invitation)
  end

  test "returns error for non-existent invitation" do
    site = insert(:site)

    assert {:error, :invitation_not_found} =
             RemoveInvitation.remove_invitation("does_not_exist", site)
  end

  test "does not allow removing invitation from another site" do
    inviter = insert(:user)
    invitee = insert(:user)
    site = insert(:site, members: [inviter])
    other_site = insert(:site, members: [inviter])

    invitation =
      insert(:invitation,
        site_id: site.id,
        inviter: inviter,
        email: invitee.email,
        role: :admin
      )

    assert {:error, :invitation_not_found} =
             RemoveInvitation.remove_invitation(invitation.invitation_id, other_site)

    assert Repo.reload(invitation)
  end
end
