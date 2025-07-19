defmodule Plausible.TeamsTest do
  use Plausible.DataCase, async: true
  use Plausible
  use Plausible.Teams.Test

  alias Plausible.Billing.Subscription
  alias Plausible.Teams
  alias Plausible.Repo

  require Plausible.Billing.Subscription.Status

  describe "name/1" do
    test "returns default name when there's no team" do
      assert Teams.name(nil) == "Meine Websites"
    end

    test "returns default name when team setup is not completed yet" do
      user = new_user(team: [setup_complete: false, name: "Foo"])
      team = team_of(user)

      assert Teams.name(team) == "Meine Websites"
    end

    test "returns team name for a setup team" do
      user = new_user(team: [setup_complete: true, name: "Foo"])
      team = team_of(user)

      assert Teams.name(team) == "Foo"
    end
  end

  describe "get_or_create/1" do
    test "creates 'Meine Websites' if user is a member of no teams" do
      today = Date.utc_today()
      user = new_user()
      user_id = user.id

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.name == "Meine Websites"
      assert Date.compare(team.trial_expiry_date, today) == :gt

      assert [
               %{user_id: ^user_id, role: :owner, is_autocreated: true}
             ] = Repo.preload(team, :team_memberships).team_memberships
    end

    @tag :ee_only
    test "sets hourly API request limit to 600 in EE" do
      user = new_user()
      assert {:ok, team} = Teams.get_or_create(user)

      assert team.hourly_api_request_limit == 600
    end

    @tag :ce_build_only
    test "sets hourly API request limit to 1000000 in CE" do
      user = new_user()
      assert {:ok, team} = Teams.get_or_create(user)

      assert team.hourly_api_request_limit == 1_000_000
    end

    test "returns existing team if user already owns one" do
      user = new_user(trial_expiry_date: ~D[2020-04-01])
      user_id = user.id
      existing_team = team_of(user)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id == existing_team.id
      assert Date.compare(team.trial_expiry_date, ~D[2020-04-01])
      assert team.name == "Meine Websites"

      assert [
               %{user_id: ^user_id, role: :owner, is_autocreated: true}
             ] = Repo.preload(team, :team_memberships).team_memberships
    end

    test "returns existing owned team even if explicitly assigned as owner" do
      user = new_user()
      user_id = user.id
      site = new_site()
      existing_team = site.team
      add_member(existing_team, user: user, role: :owner)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id == existing_team.id

      assert [
               %{role: :owner},
               %{user_id: ^user_id, role: :owner, is_autocreated: false}
             ] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
               |> Enum.sort_by(& &1.id)
    end

    test "creates 'Meine Websites' if user is a guest on another team" do
      user = new_user()
      user_id = user.id
      site = new_site()
      existing_team = site.team
      add_guest(site, user: user, role: :editor)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id != existing_team.id
      assert team.name == "Meine Websites"

      assert [%{user_id: ^user_id, role: :owner, is_autocreated: true}] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
    end

    test "creates 'Meine Websites' if user is a non-owner member on existing teams" do
      user = new_user()
      user_id = user.id
      site1 = new_site()
      team1 = site1.team
      site2 = new_site()
      team2 = site2.team
      add_member(team1, user: user, role: :viewer)
      add_member(team2, user: user, role: :editor)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id != team1.id
      assert team.id != team2.id

      assert [%{user_id: ^user_id, role: :owner, is_autocreated: true}] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
    end

    test "returns existing owned team if user is also a non-owner member on existing teams" do
      user = new_user()
      _site = new_site(owner: user)
      user_id = user.id
      owned_team = team_of(user)
      site1 = new_site()
      team1 = site1.team
      site2 = new_site()
      team2 = site2.team
      add_member(team1, user: user, role: :viewer)
      add_member(team2, user: user, role: :editor)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id == owned_team.id

      assert [%{user_id: ^user_id, role: :owner, is_autocreated: true}] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
    end

    test "returns error if user is an owner of more than one team already" do
      user = new_user()
      site1 = new_site()
      team1 = site1.team
      site2 = new_site()
      team2 = site2.team
      add_member(team1, user: user, role: :owner)
      add_member(team2, user: user, role: :owner)

      assert {:error, :multiple_teams} = Teams.get_or_create(user)
    end
  end

  on_ee do
    describe "get_or_create/1 - SSO user" do
      setup [:create_user, :create_team, :setup_sso, :provision_sso_user]

      test "does not allow creating personal team to SSO user", %{user: user} do
        assert {:error, :permission_denied} = Teams.get_or_create(user)
      end
    end

    describe "force_create_my_team/1 - SSO user" do
      setup [:create_user, :create_team, :setup_sso, :provision_sso_user]

      test "crashes when trying to create a team for SSO user", %{user: user} do
        assert_raise RuntimeError, ~r/SSO user tried to force create a personal team/, fn ->
          Teams.force_create_my_team(user)
        end
      end
    end
  end

  describe "get_by_owner/1" do
    test "returns error if user does not own any team" do
      user = new_user()

      assert {:error, :no_team} = Teams.get_by_owner(user)
    end

    test "returns error if user does not exist anymore" do
      user = new_user()
      _site = new_site(owner: user)
      Repo.delete!(user)

      assert {:error, :no_team} = Teams.get_by_owner(user)
    end

    test "returns existing 'Meine Websites' if user already owns one" do
      user = new_user(trial_expiry_date: ~D[2020-04-01])
      user_id = user.id
      existing_team = team_of(user)

      assert {:ok, team} = Teams.get_by_owner(user)

      assert team.id == existing_team.id
      assert Date.compare(team.trial_expiry_date, ~D[2020-04-01])
      assert team.name == "Meine Websites"

      assert [
               %{user_id: ^user_id, role: :owner, is_autocreated: true}
             ] = Repo.preload(team, :team_memberships).team_memberships
    end

    test "returns existing owned team if explicitly assigned as owner" do
      user = new_user()
      user_id = user.id
      site = new_site()
      existing_team = site.team
      add_member(existing_team, user: user, role: :owner)

      assert {:ok, team} = Teams.get_by_owner(user)

      assert team.id == existing_team.id

      assert [
               %{role: :owner},
               %{user_id: ^user_id, role: :owner, is_autocreated: false}
             ] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
               |> Enum.sort_by(& &1.id)
    end

    test "returns existing owned team if user is also a non-owner member on existing teams" do
      user = new_user()
      _site = new_site(owner: user)
      user_id = user.id
      owned_team = team_of(user)
      site1 = new_site()
      team1 = site1.team
      site2 = new_site()
      team2 = site2.team
      add_member(team1, user: user, role: :viewer)
      add_member(team2, user: user, role: :editor)

      assert {:ok, team} = Teams.get_by_owner(user)

      assert team.id == owned_team.id

      assert [%{user_id: ^user_id, role: :owner, is_autocreated: true}] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
    end

    test "returns error if user is an owner of more than one team" do
      user = new_user()
      site1 = new_site()
      team1 = site1.team
      site2 = new_site()
      team2 = site2.team
      add_member(team1, user: user, role: :owner)
      add_member(team2, user: user, role: :owner)

      assert {:error, :multiple_teams} = Teams.get_by_owner(user)
    end
  end

  describe "trial_days_left" do
    test "is 30 days for new signup" do
      user = new_user(trial_expiry_date: Teams.Team.trial_expiry())

      on_ee do
        assert Teams.trial_days_left(team_of(user)) == 30
      else
        assert Teams.trial_days_left(team_of(user)) > 1000
      end
    end

    test "is based on trial_expiry_date" do
      user = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: 1))

      assert Teams.trial_days_left(team_of(user)) == 1
    end
  end

  describe "on_trial?" do
    @describetag :ee_only
    test "is true with >= 0 trial days left" do
      user = new_user(trial_expiry_date: Date.utc_today())

      assert Teams.on_trial?(team_of(user))
    end

    test "is false with < 0 trial days left" do
      user = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))

      refute Teams.on_trial?(team_of(user))
    end

    test "is false if user has subscription" do
      user = new_user(trial_expiry_date: Date.utc_today())
      subscribe_to_growth_plan(user)

      refute Teams.on_trial?(team_of(user))
    end
  end

  describe "update_accept_traffic_until" do
    @describetag :ee_only
    test "update" do
      user = new_user()
      {:ok, team} = Teams.get_or_create(user)
      team = Teams.start_trial(team)
      # 30 for trial + 14
      assert Date.diff(team.accept_traffic_until, Date.utc_today()) ==
               30 + Teams.Team.trial_accept_traffic_until_offset_days()

      future = Date.add(Date.utc_today(), 30)
      subscribe_to_growth_plan(user, next_bill_date: future)

      assert updated_team = Teams.update_accept_traffic_until(team)

      assert Date.diff(updated_team.accept_traffic_until, future) ==
               Teams.Team.subscription_accept_traffic_until_offset_days()
    end

    test "retrieve: trial + 14 days" do
      user = new_user()
      {:ok, team} = Teams.get_or_create(user)
      team = Teams.start_trial(team)

      assert Teams.accept_traffic_until(Repo.reload!(team)) ==
               Date.utc_today()
               |> Date.add(30 + Teams.Team.trial_accept_traffic_until_offset_days())
    end

    test "retrieve: last_bill_date + 30 days" do
      future = Date.add(Date.utc_today(), 30)
      user = new_user() |> subscribe_to_growth_plan(next_bill_date: future)

      assert Teams.accept_traffic_until(team_of(user)) ==
               future |> Date.add(Teams.Team.subscription_accept_traffic_until_offset_days())
    end

    test "retrieve: free plan" do
      user = new_user() |> subscribe_to_plan("free_10k")

      assert Teams.accept_traffic_until(team_of(user)) == ~D[2135-01-01]
    end
  end

  describe "delete/1" do
    test "deletes a team" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.deleted())
      subscribe_to_enterprise_plan(user, site_limit: 1, subscription?: false)
      team = team_of(user)
      team = Teams.complete_setup(team)

      another_user = new_user()
      another_site = new_site(owner: another_user)
      another_team = team_of(another_user)
      add_member(another_team, user: user, role: :owner)

      site1 = new_site(team: team)
      site2 = new_site(team: team)

      viewer_member = new_user()
      add_member(team, user: viewer_member, role: :viewer)
      owner_member = new_user()
      add_member(team, user: owner_member, role: :owner)

      guest_member = new_user()
      add_guest(site1, user: guest_member, role: :editor)

      team_invitee = new_user()
      invite_member(team, team_invitee, inviter: user, role: :admin)
      guest_invitee = new_user()
      invite_guest(site2, guest_invitee, inviter: user, role: :viewer)

      assert {:ok, :deleted} = Teams.delete(team)

      refute Repo.reload(team)

      assert Repo.reload(another_user)
      assert Repo.reload(another_team)
      assert Repo.reload(another_site)

      refute Repo.reload(site1)
      refute Repo.reload(site2)

      assert Repo.reload(viewer_member)
      refute_team_member(viewer_member, team)

      assert Repo.reload(owner_member)
      refute_team_member(owner_member, team)

      assert Repo.reload(guest_member)
      refute_team_member(guest_member, team)

      assert Repo.reload(team_invitee)
      refute_team_invitation(team, team_invitee.email)

      assert Repo.reload(guest_invitee)
      refute_team_invitation(team, guest_invitee.email)
    end

    test "does not delete a team with active subscription" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.active())
      team = team_of(user)

      assert {:error, :active_subscription} = Teams.delete(team)

      assert Repo.reload(team)
    end
  end
end
