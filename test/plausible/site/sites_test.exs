defmodule Plausible.SitesTest do
  use Plausible.DataCase
  use Bamboo.Test

  alias Plausible.Sites

  describe "is_member?" do
    test "is true if user is a member of the site" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert Sites.is_member?(user.id, site)
    end

    test "is false if user is not a member" do
      user = insert(:user)
      site = insert(:site)

      refute Sites.is_member?(user.id, site)
    end
  end

  describe "stats_start_date" do
    test "is nil if site has no stats" do
      site = insert(:site)

      assert Sites.stats_start_date(site) == nil
    end

    test "is date if first pageview if site does have stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.stats_start_date(site) == Timex.today(site.timezone)
    end

    test "memoizes value of start date" do
      site = insert(:site)

      assert site.stats_start_date == nil

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.stats_start_date(site) == Timex.today(site.timezone)
      assert Repo.reload!(site).stats_start_date == Timex.today(site.timezone)
    end
  end

  describe "has_stats?" do
    test "is false if site has no stats" do
      site = insert(:site)

      refute Sites.has_stats?(site)
    end

    test "is true if site has stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.has_stats?(site)
    end
  end

  describe "invite/4" do
    test "creates an invitation" do
      inviter = insert(:user)
      invitee = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               Sites.invite(site, inviter, invitee.email, :viewer)
    end

    test "returns validation errors" do
      inviter = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:error, changeset} = Sites.invite(site, inviter, "", :viewer)
      assert {"can't be blank", _} = changeset.errors[:email]
    end

    test "returns error when user is already a member" do
      inviter = insert(:user)
      invitee = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: inviter, role: :owner),
            build(:site_membership, user: invitee, role: :viewer)
          ]
        )

      assert {:error, :already_a_member} = Sites.invite(site, inviter, invitee.email, :viewer)
      assert {:error, :already_a_member} = Sites.invite(site, inviter, inviter.email, :viewer)
    end

    test "sends invitation email for existing users" do
      [inviter, invitee] = insert_list(2, :user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               Sites.invite(site, inviter, invitee.email, :viewer)

      assert_email_delivered_with(
        to: [nil: invitee.email],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )
    end

    test "sends invitation email for new users" do
      inviter = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               Sites.invite(site, inviter, "vini@plausible.test", :viewer)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: "[Plausible Analytics] You've been invited to #{site.domain}"
      )
    end

    test "returns error when owner is over their team member limit" do
      [owner, inviter, invitee] = insert_list(3, :user)

      memberships =
        [
          build(:site_membership, user: owner, role: :owner),
          build(:site_membership, user: inviter, role: :admin)
        ] ++ build_list(4, :site_membership)

      site = insert(:site, memberships: memberships)
      assert {:error, {:over_limit, 5}} = Sites.invite(site, inviter, invitee.email, :viewer)
    end

    test "sends ownership transfer email when invitee role is owner" do
      inviter = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:ok, %Plausible.Auth.Invitation{}} =
               Sites.invite(site, inviter, "vini@plausible.test", :owner)

      assert_email_delivered_with(
        to: [nil: "vini@plausible.test"],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site.domain}"
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

      assert {:error, :forbidden} = Sites.invite(site, inviter, "vini@plausible.test", :owner)
    end

    test "does not check for limits when transferring ownership" do
      inviter = insert(:user)

      memberships =
        [build(:site_membership, user: inviter, role: :owner)] ++ build_list(5, :site_membership)

      site = insert(:site, memberships: memberships)
      assert {:ok, _invitation} = Sites.invite(site, inviter, "newowner@plausible.test", :owner)
    end

    test "does not allow viewers to invite users" do
      inviter = insert(:user)

      site =
        insert(:site,
          memberships: [
            build(:site_membership, user: build(:user), role: :owner),
            build(:site_membership, user: inviter, role: :viewer)
          ]
        )

      assert {:error, :forbidden} = Sites.invite(site, inviter, "vini@plausible.test", :viewer)
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
               Sites.invite(site, inviter, "vini@plausible.test", :admin)
    end
  end

  describe "bulk_transfer_ownership/4" do
    test "initiates ownership transfer for multiple sites in one action" do
      admin_user = insert(:user)
      new_owner = insert(:user)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: admin_user, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: admin_user, role: :owner)])

      assert {:ok, _} = Sites.bulk_transfer_ownership([site1, site2], admin_user, new_owner.email)

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site1.domain}"
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
        subject: "[Plausible Analytics] Request to transfer ownership of #{site2.domain}"
      )

      assert_invitation_exists(site2, new_owner.email, :owner)
    end

    test "initiates ownership transfer for multiple sites in one action skipping permission checks" do
      superadmin_user = insert(:user)
      new_owner = insert(:user)

      site1 = insert(:site)
      site2 = insert(:site)

      assert {:ok, _} =
               Sites.bulk_transfer_ownership([site1, site2], superadmin_user, new_owner.email,
                 check_permissions: false
               )

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site1.domain}"
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
        subject: "[Plausible Analytics] Request to transfer ownership of #{site2.domain}"
      )

      assert_invitation_exists(site2, new_owner.email, :owner)
    end
  end

  describe "get_for_user/2" do
    test "get site for super_admin" do
      user1 = insert(:user)
      user2 = insert(:user)
      patch_env(:super_admin_user_ids, [user2.id])

      %{id: site_id, domain: domain} = insert(:site, members: [user1])
      assert %{id: ^site_id} = Sites.get_for_user(user1.id, domain)
      assert %{id: ^site_id} = Sites.get_for_user(user1.id, domain, [:owner])

      assert is_nil(Sites.get_for_user(user2.id, domain))
      assert %{id: ^site_id} = Sites.get_for_user(user2.id, domain, [:super_admin])
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
