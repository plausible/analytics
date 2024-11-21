defmodule Plausible.Site.Memberships.AcceptInvitationTest do
  use Plausible
  require Plausible.Billing.Subscription.Status
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test

  alias Plausible.Site.Memberships.AcceptInvitation

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "bulk_transfer_ownership_direct/2" do
    test "transfers ownership for multiple sites in one action" do
      current_owner = insert(:user)
      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      assert {:ok, _} = AcceptInvitation.bulk_transfer_ownership_direct([site1, site2], new_owner)

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site1.id,
               user_id: new_owner.id,
               role: :owner
             )

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site2.id,
               user_id: new_owner.id,
               role: :owner
             )

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site1.id,
               user_id: current_owner.id,
               role: :admin
             )

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site2.id,
               user_id: current_owner.id,
               role: :admin
             )
    end

    test "returns error when user is already an owner for one of the sites" do
      current_owner = insert(:user)
      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 = insert(:site, memberships: [build(:site_membership, user: new_owner, role: :owner)])

      assert {:error, :transfer_to_self} =
               AcceptInvitation.bulk_transfer_ownership_direct([site1, site2], new_owner)

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site1.id,
               user_id: current_owner.id,
               role: :owner
             )

      assert Repo.get_by(Plausible.Site.Membership,
               site_id: site2.id,
               user_id: new_owner.id,
               role: :owner
             )
    end

    @tag :ee_only
    test "does not allow transferring ownership to a non-member user when at team members limit" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      site =
        insert(:site,
          memberships:
            [build(:site_membership, user: old_owner, role: :owner)] ++
              build_list(3, :site_membership, role: :admin)
        )

      assert {:error, {:over_plan_limits, [:team_member_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end

    @tag :ee_only
    test "allows transferring ownership to existing site member when at team members limit" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      site =
        insert(:site,
          memberships:
            [
              build(:site_membership, user: old_owner, role: :owner),
              build(:site_membership, user: new_owner, role: :admin)
            ] ++
              build_list(2, :site_membership, role: :admin)
        )

      assert {:ok, _} =
               AcceptInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      insert_list(10, :site, members: [new_owner])

      site = insert(:site, members: [old_owner])

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end

    @tag :ee_only
    test "exceeding limits error takes precedence over missing features" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      insert_list(10, :site, members: [new_owner])

      site =
        insert(:site,
          props_enabled: true,
          allowed_event_props: ["author"],
          memberships:
            [build(:site_membership, user: old_owner, role: :owner)] ++
              build_list(3, :site_membership, role: :admin)
        )

      assert {:error, {:over_plan_limits, [:team_member_limit, :site_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end
  end

  describe "transfer_ownership/3" do
    test "transfers ownership successfully" do
      site = insert(:site, memberships: [])

      existing_owner = insert(:user)

      existing_membership =
        insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      assert {:ok, new_membership} =
               AcceptInvitation.transfer_ownership(site, new_owner)

      assert new_membership.site_id == site.id
      assert new_membership.user_id == new_owner.id
      assert new_membership.role == :owner

      existing_membership = Repo.reload!(existing_membership)
      assert existing_membership.user_id == existing_owner.id
      assert existing_membership.site_id == site.id
      assert existing_membership.role == :admin

      assert_no_emails_delivered()
    end

    test "transfers ownership with pending invites" do
      existing_owner = new_user()
      site = new_site(owner: existing_owner)

      invite_guest(site, "some@example.com", role: :viewer, inviter: existing_owner)

      new_owner = new_user() |> subscribe_to_growth_plan()

      assert {:ok, _new_membership} =
               AcceptInvitation.transfer_ownership(site, new_owner)
    end

    @tag :teams
    test "syncs ownership transfers provided memberships exist already" do
      site = insert(:site, memberships: [])
      existing_owner = insert(:user)

      _existing_membership =
        insert(:site_membership, user: existing_owner, site: site, role: :owner)

      {:ok, old_team} = Plausible.Teams.get_or_create(existing_owner)

      another_user = insert(:user)

      insert(:site_membership, user: another_user, site: site, role: :viewer)

      another_team_membership =
        insert(:team_membership, user: another_user, team: old_team, role: :guest)

      _another_guest_membership =
        insert(:guest_membership,
          team_membership: another_team_membership,
          site: site,
          role: :viewer
        )

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      assert {:ok, new_membership} =
               AcceptInvitation.transfer_ownership(site, new_owner)

      assert new_membership.site_id == site.id
      assert new_membership.user_id == new_owner.id
      assert new_membership.role == :owner

      team = assert_team_exists(new_owner)
      assert team.id != old_team.id
      assert_team_attached(site, team.id)

      assert_guest_membership(team, site, another_user, :viewer)
      assert_guest_membership(team, site, existing_owner, :editor)
    end

    @tag :ee_only
    test "unlocks the site if it was previously locked" do
      site = insert(:site, locked: true, memberships: [])
      existing_owner = insert(:user)

      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      assert {:ok, new_membership} =
               AcceptInvitation.transfer_ownership(site, new_owner)

      assert new_membership.site_id == site.id
      assert new_membership.user_id == new_owner.id
      assert new_membership.role == :owner

      refute Repo.reload!(site).locked
    end

    for role <- [:viewer, :admin] do
      test "upgrades existing #{role} membership into an owner" do
        existing_owner = insert(:user)
        new_owner = insert(:user)
        insert(:growth_subscription, user: new_owner)

        site =
          insert(:site,
            memberships: [
              build(:site_membership, user: existing_owner, role: :owner),
              build(:site_membership, user: new_owner, role: unquote(role))
            ]
          )

        assert {:ok, %{id: membership_id}} = AcceptInvitation.transfer_ownership(site, new_owner)

        assert %{role: :admin} =
                 Plausible.Repo.get_by(Plausible.Site.Membership, user_id: existing_owner.id)

        assert %{id: ^membership_id, role: :owner} =
                 Plausible.Repo.get_by(Plausible.Site.Membership, user_id: new_owner.id)
      end
    end

    test "trial transferring to themselves gets a transfer_to_self error" do
      owner = insert(:user, trial_expiry_date: nil)
      site = insert(:site, memberships: [build(:site_membership, user: owner, role: :owner)])

      assert {:error, :transfer_to_self} = AcceptInvitation.transfer_ownership(site, owner)

      assert %{role: :owner} = Plausible.Repo.get_by(Plausible.Site.Membership, user_id: owner.id)
      assert Repo.reload!(owner).trial_expiry_date == nil
    end

    @tag :ee_only
    test "does not allow transferring to an account without an active subscription" do
      current_owner = insert(:user)
      site = insert(:site, members: [current_owner])

      trial_user = insert(:user)
      invited_user = insert(:user, trial_expiry_date: nil)

      user_on_free_10k =
        insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      user_on_expired_subscription =
        insert(:user,
          subscription:
            build(:growth_subscription,
              status: Plausible.Billing.Subscription.Status.deleted(),
              next_bill_date: Timex.shift(Timex.today(), days: -1)
            )
        )

      user_on_paused_subscription =
        insert(:user,
          subscription:
            build(:growth_subscription, status: Plausible.Billing.Subscription.Status.paused())
        )

      assert {:error, :no_plan} = AcceptInvitation.transfer_ownership(site, trial_user)
      assert {:error, :no_plan} = AcceptInvitation.transfer_ownership(site, invited_user)
      assert {:error, :no_plan} = AcceptInvitation.transfer_ownership(site, user_on_free_10k)

      assert {:error, :no_plan} =
               AcceptInvitation.transfer_ownership(site, user_on_expired_subscription)

      assert {:error, :no_plan} =
               AcceptInvitation.transfer_ownership(site, user_on_paused_subscription)
    end

    test "does not allow transferring to self" do
      current_owner = insert(:user)
      site = insert(:site, members: [current_owner])

      assert {:error, :transfer_to_self} =
               AcceptInvitation.transfer_ownership(site, current_owner)
    end

    @tag :ee_only
    test "does not allow transferring to and account without suitable plan" do
      current_owner = insert(:user)
      site = insert(:site, members: [current_owner])

      new_owner =
        insert(:user, subscription: build(:growth_subscription))

      # fill site quota
      insert_list(10, :site, members: [new_owner])

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.transfer_ownership(site, new_owner)
    end

    @tag :ce_build_only
    test "allows transferring to an account without a subscription on self hosted" do
      current_owner = insert(:user)
      site = insert(:site, members: [current_owner])

      trial_user = insert(:user)
      invited_user = insert(:user, trial_expiry_date: nil)

      user_on_free_10k =
        insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      user_on_expired_subscription =
        insert(:user,
          subscription:
            build(:growth_subscription,
              status: Plausible.Billing.Subscription.Status.deleted(),
              next_bill_date: Timex.shift(Timex.today(), days: -1)
            )
        )

      user_on_paused_subscription =
        insert(:user,
          subscription:
            build(:growth_subscription, status: Plausible.Billing.Subscription.Status.paused())
        )

      assert {:ok, _} = AcceptInvitation.transfer_ownership(site, trial_user)
      assert {:ok, _} = AcceptInvitation.transfer_ownership(site, invited_user)

      assert {:ok, _} =
               AcceptInvitation.transfer_ownership(site, user_on_free_10k)

      assert {:ok, _} =
               AcceptInvitation.transfer_ownership(site, user_on_expired_subscription)

      assert {:ok, _} =
               AcceptInvitation.transfer_ownership(site, user_on_paused_subscription)
    end
  end

  describe "accept_invitation/3 - invitations" do
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
        subject: @subject_prefix <> "#{invitee.email} accepted your invitation to #{site.domain}"
      )
    end

    @tag :teams
    test "does not create redundant guest membership when owner team membership exists" do
      user = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(user)
      site = insert(:site, team: team, members: [user])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: insert(:user),
          email: user.email,
          role: :admin
        )

      {:ok, team_membership} =
        Plausible.Teams.Invitations.accept_invitation_sync(invitation, user)

      team_membership = team_membership |> Repo.reload!() |> Repo.preload(:guest_memberships)

      assert team_membership.role == :owner
      assert team_membership.guest_memberships == []
    end

    @tag :teams
    test "sync newly converted membership with team" do
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

      team = assert_team_exists(inviter)
      assert_team_attached(site, team.id)

      assert_guest_membership(team, site, invitee, :editor)
    end

    test "does not degrade role when trying to invite self as an owner" do
      user = insert(:user)

      %{memberships: [membership]} =
        site = insert(:site, memberships: [build(:site_membership, user: user, role: :owner)])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: user,
          email: user.email,
          role: :admin
        )

      assert {:ok, invited_membership} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, user)

      assert invited_membership.id == membership.id
      membership = Repo.reload!(membership)
      assert membership.role == :owner
      assert membership.site_id == site.id
      assert membership.user_id == user.id
      refute Repo.reload(invitation)
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

    test "returns an error on non-existent invitation" do
      invitee = insert(:user)

      assert {:error, :invitation_not_found} =
               AcceptInvitation.accept_invitation("does_not_exist", invitee)
    end
  end

  describe "accept_invitation/3 - ownership transfers" do
    test "converts an ownership transfer into a membership" do
      site = insert(:site, memberships: [])
      existing_owner = insert(:user)

      existing_membership =
        insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

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
                 new_owner
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
          @subject_prefix <>
            "#{new_owner.email} accepted the ownership transfer of #{site.domain}"
      )
    end

    @tag :teams
    test "syncs accepted ownership transfer to teams" do
      site = insert(:site, memberships: [])
      existing_owner = insert(:user)

      _existing_membership =
        insert(:site_membership, user: existing_owner, site: site, role: :owner)

      site = Plausible.Teams.load_for_site(site)
      old_team = site.team
      # site = Repo.reload!(site)

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: existing_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _new_membership} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )

      team = assert_team_exists(new_owner)
      assert team.id != old_team.id
      assert_team_attached(site, team.id)

      assert_guest_membership(team, site, existing_owner, :editor)
    end

    @tag :ee_only
    test "unlocks a previously locked site after transfer" do
      site = insert(:site, locked: true, memberships: [])
      existing_owner = insert(:user)

      insert(:site_membership, user: existing_owner, site: site, role: :owner)

      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

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
                 new_owner
               )

      assert new_membership.site_id == site.id
      assert new_membership.user_id == new_owner.id
      assert new_membership.role == :owner
      refute Repo.reload(invitation)

      refute Repo.reload!(site).locked
    end

    for role <- [:viewer, :admin] do
      test "upgrades existing #{role} membership into an owner" do
        existing_owner = insert(:user)
        new_owner = insert(:user)
        insert(:growth_subscription, user: new_owner)

        site =
          insert(:site,
            memberships: [
              build(:site_membership, user: existing_owner, role: :owner),
              build(:site_membership, user: new_owner, role: unquote(role))
            ]
          )

        invitation =
          insert(:invitation,
            site_id: site.id,
            inviter: existing_owner,
            email: new_owner.email,
            role: :owner
          )

        assert {:ok, %{id: membership_id}} =
                 AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

        assert %{role: :admin} =
                 Plausible.Repo.get_by(Plausible.Site.Membership, user_id: existing_owner.id)

        assert %{id: ^membership_id, role: :owner} =
                 Plausible.Repo.get_by(Plausible.Site.Membership, user_id: new_owner.id)

        refute Repo.reload(invitation)
      end
    end

    test "does note degrade or alter trial when accepting ownership transfer by self" do
      owner = insert(:user, trial_expiry_date: nil)
      insert(:growth_subscription, user: owner)
      site = insert(:site, memberships: [build(:site_membership, user: owner, role: :owner)])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: owner,
          email: owner.email,
          role: :owner
        )

      assert {:ok, %{id: membership_id}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, owner)

      assert %{id: ^membership_id, role: :owner} =
               Plausible.Repo.get_by(Plausible.Site.Membership, user_id: owner.id)

      assert Repo.reload!(owner).trial_expiry_date == nil
      refute Repo.reload(invitation)
    end

    @tag :ee_only
    test "does not allow transferring ownership to a non-member user when at team members limit" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      site =
        insert(:site,
          memberships:
            [build(:site_membership, user: old_owner, role: :owner)] ++
              build_list(3, :site_membership, role: :admin)
        )

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:error, {:over_plan_limits, [:team_member_limit]}} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "allows transferring ownership to existing site member when at team members limit" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      site =
        insert(:site,
          memberships:
            [
              build(:site_membership, user: old_owner, role: :owner),
              build(:site_membership, user: new_owner, role: :admin)
            ] ++
              build_list(2, :site_membership, role: :admin)
        )

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      insert_list(10, :site, members: [new_owner])

      site = insert(:site, members: [old_owner])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "does not allow transferring ownership when pageview limit exceeded" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      new_owner_site = insert(:site, members: [new_owner])
      old_owner_site = insert(:site, members: [old_owner])

      somewhere_last_month = NaiveDateTime.utc_now() |> Timex.shift(days: -5)
      somewhere_penultimate_month = NaiveDateTime.utc_now() |> Timex.shift(days: -35)

      generate_usage_for(new_owner_site, 5_000, somewhere_last_month)
      generate_usage_for(new_owner_site, 1_000, somewhere_penultimate_month)

      generate_usage_for(old_owner_site, 6_000, somewhere_last_month)
      generate_usage_for(old_owner_site, 10_000, somewhere_penultimate_month)

      invitation =
        insert(:invitation,
          site_id: old_owner_site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:error, {:over_plan_limits, [:monthly_pageview_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end

    @tag :ee_only
    test "allow_next_upgrade_override field has no effect when checking the pageview limit on ownership transfer" do
      old_owner = insert(:user, subscription: build(:business_subscription))

      new_owner =
        insert(:user,
          subscription: build(:growth_subscription),
          allow_next_upgrade_override: true
        )

      new_owner_site = insert(:site, members: [new_owner])
      old_owner_site = insert(:site, members: [old_owner])

      somewhere_last_month = NaiveDateTime.utc_now() |> Timex.shift(days: -5)
      somewhere_penultimate_month = NaiveDateTime.utc_now() |> Timex.shift(days: -35)

      generate_usage_for(new_owner_site, 5_000, somewhere_last_month)
      generate_usage_for(new_owner_site, 1_000, somewhere_penultimate_month)

      generate_usage_for(old_owner_site, 6_000, somewhere_last_month)
      generate_usage_for(old_owner_site, 10_000, somewhere_penultimate_month)

      invitation =
        insert(:invitation,
          site_id: old_owner_site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:error, {:over_plan_limits, [:monthly_pageview_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when many limits exceeded at once" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      insert_list(10, :site, members: [new_owner])

      site =
        insert(:site,
          props_enabled: true,
          allowed_event_props: ["author"],
          memberships:
            [build(:site_membership, user: old_owner, role: :owner)] ++
              build_list(3, :site_membership, role: :admin)
        )

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: old_owner,
          email: new_owner.email,
          role: :owner
        )

      assert {:error, {:over_plan_limits, [:team_member_limit, :site_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end
  end
end
