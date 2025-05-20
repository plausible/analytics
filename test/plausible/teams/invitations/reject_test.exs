defmodule Plausible.Teams.Invitations.RejectTest do
  use Plausible
  use Plausible.Teams.Test
  use Plausible.DataCase, async: true
  use Bamboo.Test

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  alias Plausible.Teams.Invitations.Reject

  test "rejects guest invitation and sends email to inviter" do
    inviter = new_user()
    invitee = new_user()
    site = new_site(owner: inviter)

    invitation = invite_guest(site, invitee, inviter: inviter, role: :editor)

    assert {:ok, rejected_invitation} =
             Reject.reject(invitation.invitation_id, invitee)

    assert rejected_invitation.id == invitation.id
    refute Repo.reload(rejected_invitation)

    assert_email_delivered_with(
      to: [nil: inviter.email],
      subject: @subject_prefix <> "#{invitee.email} rejected your invitation to #{site.domain}"
    )
  end

  test "rejects team invitation and sends email to inviter" do
    inviter = new_user()
    invitee = new_user()
    _site = new_site(owner: inviter)
    team = team_of(inviter)

    invitation = invite_member(team, invitee, inviter: inviter, role: :editor)

    assert {:ok, rejected_invitation} =
             Reject.reject(invitation.invitation_id, invitee)

    assert rejected_invitation.id == invitation.id
    refute Repo.reload(rejected_invitation)

    assert_email_delivered_with(
      to: [nil: inviter.email],
      subject:
        @subject_prefix <> "#{invitee.email} rejected your invitation to \"#{team.name}\" team"
    )
  end

  test "rejects site transfer and sends email to inviter" do
    inviter = new_user()
    invitee = new_user()
    site = new_site(owner: inviter)

    site_transfer = invite_transfer(site, invitee, inviter: inviter)

    assert {:ok, rejected_transfer} =
             Reject.reject(site_transfer.transfer_id, invitee)

    assert rejected_transfer.id == site_transfer.id
    refute Repo.reload(rejected_transfer)

    assert_email_delivered_with(
      to: [nil: inviter.email],
      subject:
        @subject_prefix <> "#{invitee.email} rejected the ownership transfer of #{site.domain}"
    )
  end

  test "returns error for non-existent invitation" do
    invitee = new_user()

    assert {:error, :invitation_not_found} =
             Reject.reject("does_not_exist", invitee)
  end

  test "does not allow rejecting invitation by anyone other than invitee" do
    inviter = new_user()
    invitee = new_user()
    other_user = new_user()
    site = new_site(owner: inviter)
    invitation = invite_guest(site, invitee, role: :editor, inviter: inviter)

    assert {:error, :invitation_not_found} =
             Reject.reject(invitation.invitation_id, other_user)

    assert Repo.reload(invitation)
  end
end
