defmodule Plausible.Site.Memberships.CreateInvitationTest do
  alias Plausible.Site.Memberships.CreateInvitation
  use Plausible
  use Plausible.DataCase
  use Bamboo.Test
  use Plausible.Teams.Test

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "create_invitation/4" do
    test "creates an invitation" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)
    end

    test "returns validation errors" do
      inviter = new_user()
      site = new_site(owner: inviter)

      assert {:error, changeset} = CreateInvitation.create_invitation(site, inviter, "", :viewer)
      assert {"can't be blank", _} = changeset.errors[:email]
    end

    test "returns error when user is already a member" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      add_guest(site, user: invitee, role: :viewer)

      assert {:error, :already_a_member} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      assert {:error, :already_a_member} =
               CreateInvitation.create_invitation(site, inviter, inviter.email, :viewer)
    end

    test "sends invitation email for existing users" do
      [inviter, invitee] = for _ <- 1..2, do: new_user()
      site = new_site(owner: inviter)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)

      assert_email_delivered_with(
        to: [nil: invitee.email],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    test "sends invitation email for new users" do
      inviter = new_user()
      site = new_site(owner: inviter)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :viewer)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "You've been invited to #{site.domain}"
      )
    end

    @tag :ee_only
    test "returns error when owner is over their team member limit" do
      [owner, inviter, invitee] = for _ <- 1..3, do: new_user()

      site = new_site(owner: owner)
      inviter = add_guest(site, user: inviter, role: :editor)
      for _ <- 1..4, do: add_guest(site, role: :viewer)

      assert {:error, {:over_limit, 3}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :viewer)
    end

    @tag :ee_only
    test "allows inviting users who were already invited to other sites, within the limit" do
      owner = new_user()
      site = new_site(owner: owner)

      invite = fn site, email ->
        CreateInvitation.create_invitation(site, owner, email, :viewer)
      end

      assert {:ok, _} = invite.(site, "i1@example.com")
      assert {:ok, _} = invite.(site, "i2@example.com")
      assert {:ok, _} = invite.(site, "i3@example.com")
      assert {:error, {:over_limit, 3}} = invite.(site, "i4@example.com")

      site2 = new_site(owner: owner)

      assert {:ok, _} = invite.(site2, "i3@example.com")
    end

    import Ecto.Query

    @tag :ee_only
    test "allows inviting users who are already members of other sites, within the limit" do
      [u1, u2, u3, u4] = for _ <- 1..4, do: new_user()
      site = new_site(owner: u1)
      add_guest(site, user: u2, role: :viewer)
      add_guest(site, user: u3, role: :viewer)
      add_guest(site, user: u4, role: :viewer)

      site2 = new_site(owner: u1)
      add_guest(site2, user: u2, role: :viewer)
      add_guest(site2, user: u3, role: :viewer)

      invite = fn site, email ->
        CreateInvitation.create_invitation(site, u1, email, :viewer)
      end

      assert {:error, {:over_limit, 3}} = invite.(site, "another@example.com")
      assert {:error, :already_a_member} = invite.(site, u4.email)
      assert {:ok, _} = invite.(site2, u4.email)
    end

    test "sends ownership transfer email when invitation role is owner" do
      inviter = new_user()
      site = new_site(owner: inviter)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "only allows owners to transfer ownership" do
      inviter = new_user()

      site = new_site()
      add_guest(site, role: :editor)

      assert {:error, :forbidden} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)
    end

    test "allows ownership transfer to existing site members" do
      inviter = new_user()
      invitee = new_user()
      site = new_site(owner: inviter)
      add_guest(site, user: invitee, role: :viewer)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, invitee.email, :owner)
    end

    test "does not allow transferring ownership to existing owner" do
      inviter = new_user(email: "vini@plausible.test")
      site = new_site(owner: inviter)

      assert {:error, :transfer_to_self} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :owner)
    end

    test "allows creating an ownership transfer even when at team member limit" do
      inviter = new_user()
      site = new_site(owner: inviter)
      for _ <- 1..3, do: add_guest(site, role: :viewer)

      assert {:ok, _invitation} =
               CreateInvitation.create_invitation(
                 site,
                 inviter,
                 "newowner@plausible.test",
                 :owner
               )
    end

    test "does not allow viewers to invite users" do
      inviter = new_user()
      owner = new_user()
      site = new_site(owner: owner)
      add_guest(site, user: inviter, role: :viewer)

      assert {:error, :forbidden} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :viewer)
    end

    test "allows admins to invite other admins" do
      inviter = new_user()
      site = new_site()
      add_guest(site, user: inviter, role: :editor)

      assert {:ok, %Plausible.Auth.Invitation{}} =
               CreateInvitation.create_invitation(site, inviter, "vini@plausible.test", :admin)
    end
  end

  describe "bulk_create_invitation/5" do
    test "initiates ownership transfer for multiple sites in one action" do
      admin_user = new_user()
      new_owner = new_user()

      site1 = new_site(owner: admin_user)
      site2 = new_site(owner: admin_user)

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
      superadmin_user = new_user()
      new_owner = new_user()

      site1 = new_site()
      site2 = new_site()

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
