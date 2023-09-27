defmodule Plausible.Site.Memberships.AcceptInvitationTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  alias Plausible.Site.Memberships.AcceptInvitation

  describe "invitations" do
    test "converts an invitation into a membership" do
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

      assert {:ok, membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, invitee)

      assert membership.site_id == site.id
      assert membership.user_id == invitee.id
      assert membership.role == :admin
      refute Repo.reload(invitation)

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject:
          "[Plausible Analytics] #{invitee.email} accepted your invitation to #{site.domain}"
      )
    end

    test "handles accepting invitation as already a member gracefully" do
      inviter = insert(:user)
      invitee = insert(:user)
      site = insert(:site, members: [inviter])
      existing_membership = insert(:site_membership, user: invitee, site: site, role: :admin)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: invitee.email,
          role: :viewer
        )

      assert {:ok, new_membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, invitee)

      assert existing_membership.id == new_membership.id
      assert existing_membership.user_id == new_membership.user_id
      assert existing_membership.site_id == new_membership.site_id
      assert existing_membership.role == new_membership.role
      assert new_membership.role == :admin
      refute Repo.reload(invitation)
    end

    test "returns an error on non-existent inviation" do
      invitee = insert(:user)

      assert {:error, :invitation_not_found} =
               AcceptInvitation.accept_invitation("does_not_exist", invitee)
    end
  end

  describe "ownership transfers" do
    for {label, opts} <- [{"cloud", []}, {"selfhosted", [selfhost?: true]}] do
      test "converts an ownership transfer into a membership on #{label} instance" do
        site = insert(:site)
        existing_owner = insert(:user)

        existing_membership =
          insert(:site_membership, user: existing_owner, site: site, role: :owner)

        new_owner = insert(:user)

        invitation =
          insert(:invitation,
            site_id: site.id,
            inviter: existing_owner,
            email: new_owner.email,
            role: :owner
          )

        assert {:ok, new_membership} =
                 AcceptInvitation.accept_invitation(
                   invitation.invitation_id,
                   new_owner,
                   unquote(opts)
                 )

        assert new_membership.site_id == site.id
        assert new_membership.user_id == new_owner.id
        assert new_membership.role == :owner
        refute Repo.reload(invitation)

        existing_membership = Repo.reload!(existing_membership)
        assert existing_membership.user_id == existing_owner.id
        assert existing_membership.site_id == site.id
        assert existing_membership.role == :admin

        assert_email_delivered_with(
          to: [nil: existing_owner.email],
          subject:
            "[Plausible Analytics] #{new_owner.email} accepted the ownership transfer of #{site.domain}"
        )
      end
    end

    for role <- [:viewer, :admin] do
      test "upgrades existing #{role} membership into an owner" do
        site = insert(:site)
        owner = insert(:user)
        owner_membership = insert(:site_membership, user: owner, site: site, role: :owner)
        new_owner = insert(:user)

        new_owner_membership =
          insert(:site_membership, user: new_owner, site: site, role: unquote(role))

        invitation =
          insert(:invitation,
            site_id: site.id,
            inviter: owner,
            email: new_owner.email,
            role: :owner
          )

        assert {:ok, membership} =
                 AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

        assert membership.id == new_owner_membership.id
        assert membership.role == :owner

        assert Repo.reload!(owner_membership).role == :admin
        refute Repo.reload(invitation)
      end
    end

    test "locks the site if the new owner has no active subscription or trial" do
      site = insert(:site, locked: false)

      existing_owner = insert(:user)
      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user, trial_expiry_date: Date.add(Date.utc_today(), -1))

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: existing_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

      assert Repo.reload!(site).locked
    end

    test "does not lock the site or set trial expiry date if the instance is selfhosted" do
      site = insert(:site, locked: false)

      existing_owner = insert(:user)
      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user, trial_expiry_date: nil)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: existing_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner,
                 selfhost?: true
               )

      assert Repo.reload!(new_owner).trial_expiry_date == nil
      refute Repo.reload!(site).locked
    end

    test "ends trial of the new owner immediately" do
      site = insert(:site, locked: false)

      existing_owner = insert(:user)
      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user, trial_expiry_date: Date.add(Date.utc_today(), 7))

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: existing_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

      assert Repo.reload!(new_owner).trial_expiry_date == Date.add(Date.utc_today(), -1)
      assert Repo.reload!(site).locked
    end

    test "sets user's trial expiry date to yesterday if they don't have one" do
      site = insert(:site, locked: false)

      existing_owner = insert(:user)
      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user, trial_expiry_date: nil)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: existing_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

      assert Repo.reload!(new_owner).trial_expiry_date == Date.add(Date.utc_today(), -1)
      assert Repo.reload!(site).locked
    end
  end
end
