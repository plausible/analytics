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
      invitee = insert(:user)
      site = insert(:site, memberships: [build(:site_membership, user: inviter, role: :owner)])

      assert {:error, changeset} = Sites.invite(site, inviter, invitee.email, :invalid_role)
      assert {"is invalid", _} = changeset.errors[:role]
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
  end
end
