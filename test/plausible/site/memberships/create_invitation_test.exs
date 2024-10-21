defmodule Plausible.Site.Memberships.CreateInvitationTest do
  alias Plausible.Site.Memberships.CreateInvitation
  use Plausible
  use Plausible.DataCase
  use Bamboo.Test
  use Plausible.Teams.Test

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "create_invitation/4" do
    test "creates an invitation" do
      inviter = insert(:user)
      invitee = insert(:user)
      team = insert(:team)

      site =
        insert(:site,
          team: team,
          memberships: [build(:site_membership, user: inviter, role: :owner)]
        )

      insert(:team_membership, team: team, user: inviter, role: :owner)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      assert {:ok, %Plausible.Teams.GuestInvitation{}} =
               Plausible.Teams.Invitations.invite(site, inviter, invitee.email, :viewer)
    end

    @tag :teams
    test "[TEAMS] syncs a created invitation" do
      inviter = insert(:user)
      invitee = insert(:user)

      site =
        insert(:site,
          team: nil,
          memberships: [build(:site_membership, user: inviter, role: :owner)]
        )

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      team = assert_team_attached(site)
      assert_guest_invitation(team, site, invitee.email, :viewer)
    end

    @tag :teams
    test "[TEAMS] sync a created invitation with team already setup but site not assigned yet" do
      inviter = insert(:user)
      invitee = insert(:user)

      {:ok, %{id: team_id}} = Plausible.Teams.get_or_create(inviter)

      site =
        insert(:site,
          team: nil,
          memberships: [build(:site_membership, user: inviter, role: :owner)]
        )

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      team = assert_team_attached(site, team_id)
      assert_guest_invitation(team, site, invitee.email, :viewer)
    end

    @tag :teams
    test "[TEAMS] sync a created invitation with team fully setup" do
      inviter = insert(:user)
      invitee = insert(:user)

      {:ok, %{id: team_id} = team} = Plausible.Teams.get_or_create(inviter)

      site =
        insert(:site,
          team: team,
          memberships: [build(:site_membership, user: inviter, role: :owner)]
        )

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      team = assert_team_attached(site, team_id)
      assert_guest_invitation(team, site, invitee.email, :viewer)
    end

    test "returns validation errors" do
      inviter = insert(:user)
      team = insert(:team)

      site =
        insert(:site,
          team: team,
          memberships: [build(:site_membership, user: inviter, role: :owner)]
        )

      insert(:team_membership, team: team, user: inviter, role: :owner)

      assert {:error, changeset} = CreateInvitation.create_invitation(site, inviter, "", :viewer)
      assert {"can't be blank", _} = changeset.errors[:email]

      assert {:error, changeset} = Plausible.Teams.Invitations.invite(site, inviter, "", :viewer)
      assert {"can't be blank", _} = changeset.errors[:email]
    end

    test "returns error when user is already a member" do
      inviter = insert(:user)
      invitee = insert(:user)

      team = insert(:team)

      site =
        insert(:site,
          team: team,
          memberships: [
            build(:site_membership, user: inviter, role: :owner),
            build(:site_membership, user: invitee, role: :viewer)
          ]
        )

      insert(:team_membership, team: team, user: inviter, role: :owner)
      team_membership = insert(:team_membership, team: team, user: invitee, role: :guest)
      insert(:guest_membership, team_membership: team_membership, site: site, role: :viewer)

      assert {:error, :already_a_member} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      assert {:error, :already_a_member} =
               Plausible.Teams.Invitations.invite(site, inviter, invitee.email, :viewer)

      assert {:error, :already_a_member} =
               CreateInvitation.create_invitation(site, inviter, inviter.email, :viewer)

      assert {:error, :already_a_member} =
               Plausible.Teams.Invitations.invite(site, inviter, inviter.email, :viewer)
    end

    test "sends invitation email for existing users" do
      [inviter, invitee] = insert_list(2, :user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      assert_email_delivered_with(
        to: [nil: invitee.email],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    test "sends invitation email for new users" do
      inviter = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :viewer)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    @tag :ee_only
    test "returns error when owner is over their team member limit" do
      [owner, inviter, invitee] = insert_list(3, :user)

      memberships =
        [
          build(:site_membership, user: owner, role: :owner),
          build(:site_membership, user: inviter, role: :admin)
        ] ++ build_list(4, :site_membership)

      site = insert(:site, memberships: memberships)

      assert {:error, {:over_limit, 3}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)
    end

    @tag :ee_only
    test "allows inviting users who were already invited to other sites, within the limit" do
      owner = insert(:user)

      memberships =
        [
          build(:site_membership, user: owner, role: :owner)
        ]

      site = insert(:site, memberships: memberships)

      invite = fn site, email ->
        CreateInvitation.create_invitation(site, owner, email, :viewer)
      end

      assert {:ok, _} = invite.(site, "i1@example.com")
      assert {:ok, _} = invite.(site, "i2@example.com")
      assert {:ok, _} = invite.(site, "i3@example.com")
      assert {:error, {:over_limit, 3}} = invite.(site, "i4@example.com")

      site2 = insert(:site, memberships: memberships)

      assert {:ok, _} = invite.(site2, "i3@example.com")
    end

    @tag :ee_only
    test "allows inviting users who are already members of other sites, within the limit" do
      [u1, u2, u3, u4] = insert_list(4, :user)

      memberships =
        [
          build(:site_membership, user: u1, role: :owner),
          build(:site_membership, user: u2, role: :viewer),
          build(:site_membership, user: u3, role: :viewer)
        ]

      site =
        insert(:site,
          memberships: memberships ++ [build(:site_membership, user: u4, role: :viewer)]
        )

      site2 = insert(:site, memberships: memberships)

      invite = fn site, email ->
        CreateInvitation.create_invitation(site, u1, email, :viewer)
      end

      assert {:error, {:over_limit, 3}} = invite.(site, "another@example.com")
      assert {:error, :already_a_member} = invite.(site, u4.email)
      assert {:ok, _} = invite.(site2, u4.email)
    end

    test "sends ownership transfer email when invitation role is owner" do
      inviter = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "only allows owners to transfer ownership" do
      inviter = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: build(:user), role: :owner),
            build(:site_membership, user: inviter, role: :admin)
          ]
        )

      assert {:error, :forbidden} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)
    end

    test "allows ownership transfer to existing site members" do
      inviter = insert(:user)
      invitee = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: inviter, role: :owner),
            build(:site_membership, user: invitee, role: :viewer)
          ]
        )

      insert(:team_membership, team: site.team, user: inviter, role: :owner)
      insert(:team_membership, team: site.team, user: invitee, role: :viewer)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :owner)

      assert {:ok, %Plausible.Teams.SiteTransfer{}} =
               Plausible.Teams.Invitations.invite(site, inviter, invitee.email, :owner)
    end

    test "does not allow transferring ownership to existing owner" do
      inviter = insert(:user, email: "vini@plausible.test")

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: inviter, role: :owner)
          ]
        )

      insert(:team_membership, team: site.team, user: inviter, role: :owner)

      assert {:error, :transfer_to_self} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)

      assert {:error, :transfer_to_self} =
               Plausible.Teams.Invitations.invite(site, inviter, "vini@plausible.test", :owner)
    end

    test "allows creating an ownership transfer even when at team member limit" do
      inviter = insert(:user)

      memberships =
        [build(:site_membership, user: inviter, role: :owner)] ++ build_list(3, :site_membership)

      site = insert(:site, memberships: memberships)

      assert {:ok, _invitation} =
               CreateInvitation.create_invitation(
                 site,
                 inviter,
                 "newowner@plausible.test",
                 :owner
               )
    end

    test "does not allow viewers to invite users" do
      inviter = insert(:user)
      owner = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: owner, role: :owner),
            build(:site_membership, user: inviter, role: :viewer)
          ]
        )

      insert(:team_membership, team: site.team, user: owner, role: :owner)
      insert(:team_membership, team: site.team, user: inviter, role: :viewer)

      assert {:error, :forbidden} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :viewer)

      assert {:error, :forbidden} =
               Plausible.Teams.Invitations.invite(site, inviter, "vini@plausible.test", :viewer)
    end

    test "allows admins to invite other admins" do
      inviter = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: build(:user), role: :owner),
            build(:site_membership, user: inviter, role: :admin)
          ]
        )

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :admin)
    end
  end

  describe "bulk_create_invitation/5" do
    test "initiates ownership transfer for multiple sites in one action" do
      admin_user = insert(:user)
      new_owner = insert(:user)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: admin_user, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: admin_user, role: :owner)])

      assert {:ok, _} =
               CreateInvitation.bulk_create_invitation(
                 [site1, site2],
                 admin_user,
                 new_owner.email,
                 :owner
               )

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site1.domain}"
      )

      assert Repo.exists?(
               from(i in Plausible.Auth.Invitation,
                 where:
                   i.site_id == ^site1.id and i.email == ^new_owner.email and i.role == :owner
               )
             )

      assert_invitation_exists(site1, new_owner.email, :owner)

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site2.domain}"
      )

      assert_invitation_exists(site2, new_owner.email, :owner)
    end

    test "initiates ownership transfer for multiple sites in one action skipping permission checks" do
      superadmin_user = insert(:user)
      new_owner = insert(:user)

      site1 = insert(:site)
      site2 = insert(:site)

      assert {:ok, _} =
               CreateInvitation.bulk_create_invitation(
                 [site1, site2],
                 superadmin_user,
                 new_owner.email,
                 :owner,
                 check_permissions: false
               )

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site1.domain}"
      )

      assert Repo.exists?(
               from(i in Plausible.Auth.Invitation,
                 where:
                   i.site_id == ^site1.id and i.email == ^new_owner.email and i.role == :owner
               )
             )

      assert_invitation_exists(site1, new_owner.email, :owner)

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site2.domain}"
      )

      assert_invitation_exists(site2, new_owner.email, :owner)
    end
  end

  describe "bulk_transfer_ownership_direct/2" do
    test "transfers ownership for multiple sites in one action" do
      current_owner = insert(:user)
      new_owner = insert(:user)
      insert(:growth_subscription, user: new_owner)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      assert {:ok, _} = CreateInvitation.bulk_transfer_ownership_direct([site1, site2], new_owner)

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
               CreateInvitation.bulk_transfer_ownership_direct([site1, site2], new_owner)

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
               CreateInvitation.bulk_transfer_ownership_direct([site], new_owner)
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
               CreateInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = insert(:user, subscription: build(:business_subscription))
      new_owner = insert(:user, subscription: build(:growth_subscription))

      insert_list(10, :site, members: [new_owner])

      site = insert(:site, members: [old_owner])

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               CreateInvitation.bulk_transfer_ownership_direct([site], new_owner)
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
               CreateInvitation.bulk_transfer_ownership_direct([site], new_owner)
    end
  end

  defp assert_invitation_exists(site, email, role) do
    assert Repo.exists?(
             from(i in Plausible.Auth.Invitation,
               where: i.site_id == ^site.id and i.email == ^email and i.role == ^role
             )
           )
  end
end
