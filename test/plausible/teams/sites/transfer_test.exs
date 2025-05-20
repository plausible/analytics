defmodule Plausible.Teams.Sites.TransferTest do
  use Plausible
  require Plausible.Billing.Subscription.Status
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test

  alias Plausible.Teams.Sites.Transfer

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "change_team/3" do
    @tag :ce_build_only
    test "changes the team if owner in both teams (CE)" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :owner)

      assert :ok = Transfer.change_team(site, user, team2)
    end

    @tag :ee_only
    test "changes the team if owner in both teams (EE)" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :owner)

      assert {:error, :no_plan} = Transfer.change_team(site, user, team2)

      subscribe_to_growth_plan(another)

      assert :ok = Transfer.change_team(site, user, team2)
      assert Repo.reload!(site).team_id == team2.id
      assert_team_membership(user, team2, :owner)

      assert_email_delivered_with(
        to: [nil: another.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )

      assert_email_delivered_with(
        to: [nil: user.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )
    end

    test "changes the team if admin in second team" do
      user = new_user()
      site = new_site(owner: user)

      another = new_user()
      subscribe_to_growth_plan(another)
      new_site(owner: another)

      team2 = team_of(another)

      add_member(team2, user: user, role: :admin)

      assert :ok = Transfer.change_team(site, user, team2)
      assert Repo.reload!(site).team_id == team2.id
      assert_team_membership(user, team2, :admin)

      assert_email_delivered_with(
        to: [nil: another.email],
        subject:
          @subject_prefix <>
            "#{user.email} has transferred #{site.domain} to \"#{team2.name}\" team"
      )
    end

    for role <- Plausible.Teams.Membership.roles() -- [:admin, :owner] do
      test "refuses to change the team if #{role} in second team" do
        user = new_user()
        site = new_site(owner: user)

        another = new_user()
        subscribe_to_growth_plan(another)
        new_site(owner: another)

        team2 = team_of(another)

        add_member(team2, user: user, role: unquote(role))

        assert {:error, :permission_denied} = Transfer.change_team(site, user, team2)
        refute Repo.reload!(site).team_id == team2.id
      end
    end
  end

  describe "bulk_transfer_ownership_direct/2" do
    test "transfers ownership for multiple sites in one action" do
      current_owner = new_user()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert {:ok, _} =
               Transfer.bulk_transfer(
                 [site1, site2],
                 new_owner
               )

      team = assert_team_exists(Repo.reload!(new_owner))
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
               Transfer.bulk_transfer(
                 [site1, site2],
                 new_owner
               )

      assert_team_membership(current_owner, site1.team, :owner)
      assert_team_membership(new_owner, site2.team, :owner)
    end

    test "does not allow transferring ownership without selecting team for owner of more than one team" do
      new_owner = new_user() |> subscribe_to_growth_plan()

      other_site1 = new_site()
      add_member(other_site1.team, user: new_owner, role: :owner)
      other_site2 = new_site()
      add_member(other_site2.team, user: new_owner, role: :owner)

      current_owner = new_user()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert {:error, :multiple_teams} =
               Transfer.bulk_transfer(
                 [site1, site2],
                 new_owner
               )
    end

    test "allows transferring between teams of the same owner" do
      current_owner = new_user() |> subscribe_to_growth_plan()
      another_owner = new_user() |> subscribe_to_growth_plan()

      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      new_team = team_of(another_owner)
      add_member(new_team, user: current_owner, role: :owner)

      assert {:ok, _} =
               Transfer.bulk_transfer(
                 [site1, site2],
                 current_owner,
                 new_team
               )
    end

    test "does not allow transferring ownership to a team where user has no permission" do
      other_owner = new_user() |> subscribe_to_growth_plan()
      other_team = team_of(other_owner)
      new_owner = new_user()
      add_member(other_team, user: new_owner, role: :viewer)

      current_owner = new_user()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert {:error, :permission_denied} =
               Transfer.bulk_transfer(
                 [site1, site2],
                 new_owner,
                 other_team
               )
    end

    test "allows transferring ownership to a team where user has permission" do
      other_owner = new_user() |> subscribe_to_growth_plan()
      other_team = team_of(other_owner)
      new_owner = new_user()
      add_member(other_team, user: new_owner, role: :admin)

      current_owner = new_user()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert {:ok, _} =
               Transfer.bulk_transfer(
                 [site1, site2],
                 new_owner,
                 other_team
               )

      assert Repo.reload(site1).team_id == other_team.id
      assert_guest_membership(other_team, site1, current_owner, :editor)
      assert Repo.reload(site2).team_id == other_team.id
      assert_guest_membership(other_team, site2, current_owner, :editor)
    end

    @tag :ee_only
    test "does not allow transferring ownership to a non-member user when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: old_owner)
      for _ <- 1..3, do: add_guest(site, role: :editor)

      assert {:error, {:over_plan_limits, [:team_member_limit]}} =
               Transfer.bulk_transfer([site], new_owner)
    end

    @tag :ee_only
    test "allows transferring ownership to existing site member when at team members limit" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: old_owner)
      add_guest(site, user: new_owner, role: :editor)
      for _ <- 1..2, do: add_guest(site, role: :editor)

      assert {:ok, _} =
               Transfer.bulk_transfer([site], new_owner)
    end

    @tag :ee_only
    test "does not allow transferring ownership when sites limit exceeded" do
      old_owner = new_user() |> subscribe_to_business_plan()
      new_owner = new_user() |> subscribe_to_growth_plan()

      for _ <- 1..10, do: new_site(owner: new_owner)

      site = new_site(owner: old_owner)

      assert {:error, {:over_plan_limits, [:site_limit]}} =
               Transfer.bulk_transfer([site], new_owner)
    end

    @tag :ee_only
    test "exceeding limits error takes precedence over missing features" do
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

      assert {:error, {:over_plan_limits, [:team_member_limit, :site_limit]}} =
               Transfer.bulk_transfer([site], new_owner)
    end
  end
end
