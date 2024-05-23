defmodule Plausible.Site.Memberships.RejectInvitationTest do
  use Plausible
  use Plausible.DataCase, async: true
  use Bamboo.Test

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  alias Plausible.Site.Memberships.RejectInvitation

  test "rejects invitation and sends email to inviter" do
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

    assert {:ok, rejected_invitation} =
             RejectInvitation.reject_invitation(invitation.invitation_id, invitee)

    assert rejected_invitation.id == invitation.id
    refute Repo.reload(rejected_invitation)

    assert_email_delivered_with(
      to: [nil: inviter.email],
      subject: @subject_prefix <> "#{invitee.email} rejected your invitation to #{site.domain}"
    )
  end

  test "returns error for non-existent invitation" do
    invitee = insert(:user)

    assert {:error, :invitation_not_found} =
             RejectInvitation.reject_invitation("does_not_exist", invitee)
  end

  test "does not allow rejecting invitation by anyone other than invitee" do
    inviter = insert(:user)
    invitee = insert(:user)
    other_user = insert(:user)
    site = insert(:site, members: [inviter])

    invitation =
      insert(:invitation,
        site_id: site.id,
        inviter: inviter,
        email: invitee.email,
        role: :admin
      )

    assert {:error, :invitation_not_found} =
             RejectInvitation.reject_invitation(invitation.invitation_id, other_user)

    assert Repo.reload(invitation)
  end
end
