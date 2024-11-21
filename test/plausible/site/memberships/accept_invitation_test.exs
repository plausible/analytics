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
      current_owner = new_user()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert {:ok, _} =
               AcceptInvitation.bulk_transfer_ownership_direct(
                 current_owner,
                 [site1, site2],
                 new_owner
               )

      team = assert_team_exists(new_owner)
      assert_team_membership(new_owner, team, :owner)
      assert_team_membership(new_owner, team, :owner)
      assert_guest_membership(team, site1, current_owner, :editor)
      assert_guest_membership(team, site2, current_owner, :editor)
    end

    test "returns error when user is already an owner for one of the sites" do
      current_owner = new_user()
      new_owner = new_user() |> subscribe_to_growth_plan()

      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: new_owner)

      assert {:error, :transfer_to_self} =
               AcceptInvitation.bulk_transfer_ownership_direct(
                 current_owner,
                 [site1, site2],
                 new_owner
               )

      assert_team_membership(current_owner, site1.team, :owner)
      assert_team_membership(new_owner, site2.team, :owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership to a non-member user when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: old_owner)
      for _ <- 1..3, do: add_guest(site, role: :editor)

      assert {:error, {:over_plan_limits, [:team_member_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct(old_owner, [site], new_owner)
    end

    @tag :ee_only
    test "allows transferring ownership to existing site member when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: old_owner)
      add_guest(site, user: new_owner, role: :editor)
      for _ <- 1..2, do: add_guest(site, role: :editor)

      assert {:ok, _} =
               AcceptInvitation.bulk_transfer_ownership_direct(old_owner, [site], new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      for _ <- 1..10, do: new_site(owner: new_owner)

      site = new_site(owner: old_owner)

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct(old_owner, [site], new_owner)
    end

    @tag :ee_only
    test "exceeding limits error takes precedence over missing features" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      insert_list(10, :site, members: [new_owner])
      for _ <- 1..10, do: new_site(owner: new_owner)

      site =
        new_site(
          owner: old_owner,
          props_enabled: true,
          allowed_event_props: ["author"]
        )

      for _ <- 1..3, do: add_guest(site, role: :editor)

      assert {:error, {:over_plan_limits, [:team_member_limit, :site_limit]}} =
               AcceptInvitation.bulk_transfer_ownership_direct(old_owner, [site], new_owner)
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
      existing_owner = new_user()
      site = new_site(owner: existing_owner)

      new_owner = new_user() |> subscribe_to_growth_plan()
      new_team = team_of(new_owner)

      invitation = invite_transfer(site, new_owner, inviter: existing_owner)

      assert {:ok, _new_membership} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )

      assert_team_attached(site, new_team.id)

      refute Repo.reload(invitation)

      assert_guest_membership(new_team, site, existing_owner, :editor)

      assert_email_delivered_with(
        to: [nil: existing_owner.email],
        subject:
          @subject_prefix <>
            "#{new_owner.email} accepted the ownership transfer of #{site.domain}"
      )
    end

    test "transfers ownership with pending invites" do
      existing_owner = new_user()
      site = new_site(owner: existing_owner)
      invite_guest(site, "some@example.com", role: :viewer, inviter: existing_owner)
      new_owner = new_user() |> subscribe_to_growth_plan()
      new_team = team_of(new_owner)

      site_transfer =
        invite_transfer(site, new_owner, inviter: existing_owner)

      assert {:ok, _new_membership} =
               AcceptInvitation.accept_invitation(site_transfer.invitation_id, new_owner)

      assert_guest_invitation(new_team, site, "some@example.com", :viewer)
      assert_team_attached(site, new_team.id)
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
      existing_owner = new_user()
      site = new_site(owner: existing_owner, locked: true)
      new_owner = new_user() |> subscribe_to_growth_plan()

      invitation = invite_transfer(site, new_owner, inviter: existing_owner)

      assert {:ok, _new_membership} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )

      refute Repo.reload(invitation)

      refute Repo.reload!(site).locked
    end

    for role <- [:viewer, :editor] do
      test "upgrades existing #{role} membership into an owner" do
        existing_owner = new_user()
        new_owner = new_user() |> subscribe_to_growth_plan()
        new_team = team_of(new_owner)

        site = new_site(owner: existing_owner)
        add_guest(site, user: new_owner, role: unquote(role))

        invitation =
          invite_transfer(site, new_owner, inviter: existing_owner)

        assert {:ok, _} =
                 AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)

        assert_guest_membership(new_team, site, existing_owner, :editor)

        assert_team_membership(new_owner, new_team, :owner)

        refute Repo.reload(invitation)
      end
    end

    @tag :ee_only
    test "does not allow transferring ownership to a non-member user when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: old_owner)

      for _ <- 1..3, do: add_guest(site, role: :editor)

      invitation = invite_transfer(site, new_owner, inviter: old_owner)

      assert {:error, {:over_plan_limits, [:team_member_limit]}} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "allows transferring ownership to existing site member when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      site = new_site(owner: old_owner)

      add_guest(site, user: new_owner, role: :editor)
      for _ <- 1..2, do: add_guest(site, role: :editor)

      invitation = invite_transfer(site, new_owner, inviter: old_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      for _ <- 1..10, do: new_site(owner: new_owner)

      site = new_site(owner: old_owner)

      invitation = invite_transfer(site, new_owner, inviter: old_owner)

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.accept_invitation(
                 invitation.invitation_id,
                 new_owner
               )
    end

    @tag :ee_only
    test "does not allow transferring ownership when pageview limit exceeded" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      new_owner_site = new_site(owner: new_owner)
      old_owner_site = new_site(owner: old_owner)

      somewhere_last_month = NaiveDateTime.utc_now() |> Timex.shift(days: -5)
      somewhere_penultimate_month = NaiveDateTime.utc_now() |> Timex.shift(days: -35)

      generate_usage_for(new_owner_site, 5_000, somewhere_last_month)
      generate_usage_for(new_owner_site, 1_000, somewhere_penultimate_month)

      generate_usage_for(old_owner_site, 6_000, somewhere_last_month)
      generate_usage_for(old_owner_site, 10_000, somewhere_penultimate_month)

      invitation = invite_transfer(old_owner_site, new_owner, inviter: old_owner)

      assert {:error, {:over_plan_limits, [:monthly_pageview_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end

    @tag :ee_only
    test "allow_next_upgrade_override field has no effect when checking the pageview limit on ownership transfer" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user(allow_next_upgrade_override: true) |> subscribe_to_growth_plan()

      new_owner_site = new_site(owner: new_owner)
      old_owner_site = new_site(owner: old_owner)

      somewhere_last_month = NaiveDateTime.utc_now() |> Timex.shift(days: -5)
      somewhere_penultimate_month = NaiveDateTime.utc_now() |> Timex.shift(days: -35)

      generate_usage_for(new_owner_site, 5_000, somewhere_last_month)
      generate_usage_for(new_owner_site, 1_000, somewhere_penultimate_month)

      generate_usage_for(old_owner_site, 6_000, somewhere_last_month)
      generate_usage_for(old_owner_site, 10_000, somewhere_penultimate_month)

      invitation = invite_transfer(old_owner_site, new_owner, inviter: old_owner)

      assert {:error, {:over_plan_limits, [:monthly_pageview_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when many limits exceeded at once" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      for _ <- 1..10, do: new_site(owner: new_owner)

      site =
        new_site(
          owner: old_owner,
          props_enabled: true,
          allowed_event_props: ["author"]
        )

      for _ <- 1..3, do: add_guest(site, role: :editor)

      invitation = invite_transfer(site, new_owner, inviter: old_owner)

      assert {:error, {:over_plan_limits, [:team_member_limit, :site_limit]}} =
               AcceptInvitation.accept_invitation(invitation.invitation_id, new_owner)
    end

    @tag :ee_only
    test "does not allow transferring to an account without an active subscription" do
      current_owner = new_user()
      site = new_site(owner: current_owner)

      trial_user = new_user()
      invited_user = new_user(trial_expiry_date: nil)
      user_on_free_10k = new_user() |> subscribe_to_plan("free_10k")

      user_on_expired_subscription =
        new_user()
        |> subscribe_to_growth_plan(
          status: Plausible.Billing.Subscription.Status.deleted(),
          next_bill_date: Timex.shift(Timex.today(), days: -1)
        )

      user_on_paused_subscription =
        new_user()
        |> subscribe_to_growth_plan(status: Plausible.Billing.Subscription.Status.paused())

      transfer = invite_transfer(site, trial_user, inviter: current_owner)

      assert {:error, :no_plan} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, trial_user)

      Repo.delete!(transfer)

      transfer = invite_transfer(site, invited_user, inviter: current_owner)

      assert {:error, :no_plan} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, invited_user)

      Repo.delete!(transfer)

      transfer = invite_transfer(site, user_on_free_10k, inviter: current_owner)

      assert {:error, :no_plan} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, user_on_free_10k)

      Repo.delete!(transfer)

      transfer = invite_transfer(site, user_on_expired_subscription, inviter: current_owner)

      assert {:error, :no_plan} =
               AcceptInvitation.accept_invitation(
                 transfer.invitation_id,
                 user_on_expired_subscription
               )

      Repo.delete!(transfer)

      transfer = invite_transfer(site, user_on_paused_subscription, inviter: current_owner)

      assert {:error, :no_plan} =
               AcceptInvitation.accept_invitation(
                 transfer.invitation_id,
                 user_on_paused_subscription
               )

      Repo.delete!(transfer)
    end

    test "does not allow transferring to self" do
      current_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: current_owner)

      transfer = invite_transfer(site, current_owner, inviter: current_owner)

      assert {:error, :transfer_to_self} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, current_owner)
    end

    @tag :ee_only
    test "does not allow transferring to and account without suitable plan" do
      current_owner = new_user()
      site = new_site(owner: current_owner)
      new_owner = new_user() |> subscribe_to_growth_plan()

      # fill site quota
      for _ <- 1..10, do: new_site(owner: new_owner)
      insert_list(10, :site, members: [new_owner])

      transfer = invite_transfer(site, new_owner, inviter: current_owner)

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, new_owner)
    end

    @tag :ce_build_only
    test "allows transferring to an account without a subscription on self hosted" do
      current_owner = new_user()
      site = new_site(owner: current_owner)

      trial_user = new_user()
      invited_user = new_user(trial_expiry_date: nil)
      user_on_free_10k = new_user() |> subscribe_to_plan("free_10k")

      user_on_expired_subscription =
        new_user()
        |> subscribe_to_growth_plan(
          status: Plausible.Billing.Subscription.Status.deleted(),
          next_bill_date: Timex.shift(Timex.today(), days: -1)
        )

      user_on_paused_subscription =
        new_user()
        |> subscribe_to_growth_plan(status: Plausible.Billing.Subscription.Status.paused())

      transfer = invite_transfer(site, trial_user, inviter: current_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, trial_user)

      transfer = invite_transfer(site, invited_user, inviter: current_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, invited_user)

      transfer = invite_transfer(site, user_on_free_10k, inviter: current_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(transfer.invitation_id, user_on_free_10k)

      transfer = invite_transfer(site, user_on_expired_subscription, inviter: current_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(
                 transfer.invitation_id,
                 user_on_expired_subscription
               )

      transfer = invite_transfer(site, user_on_paused_subscription, inviter: current_owner)

      assert {:ok, _} =
               AcceptInvitation.accept_invitation(
                 transfer.invitation_id,
                 user_on_paused_subscription
               )
    end
  end
end
