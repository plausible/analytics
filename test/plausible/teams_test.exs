defmodule Plausible.TeamsTest do
  use Plausible.DataCase, async: true
  use Plausible
  use Plausible.Teams.Test

  alias Plausible.Teams
  alias Plausible.Repo

  describe "get_or_create/1" do
    test "creates 'My Personal Sites' if user is a member of no teams" do
      today = Date.utc_today()
      user = new_user()
      user_id = user.id

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.name == "My Personal Sites"
      assert Date.compare(team.trial_expiry_date, today) == :gt

      assert [
               %{user_id: ^user_id, role: :owner, is_autocreated: true}
             ] = Repo.preload(team, :team_memberships).team_memberships
    end

    test "returns existing team if user already owns one" do
      user = new_user(trial_expiry_date: ~D[2020-04-01])
      user_id = user.id
      existing_team = team_of(user)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id == existing_team.id
      assert Date.compare(team.trial_expiry_date, ~D[2020-04-01])
      assert team.name == "My Personal Sites"

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

    test "creates 'My Personal Sites' if user is a guest on another team" do
      user = new_user()
      user_id = user.id
      site = new_site()
      existing_team = site.team
      add_guest(site, user: user, role: :editor)

      assert {:ok, team} = Teams.get_or_create(user)

      assert team.id != existing_team.id
      assert team.name == "My Personal Sites"

      assert [%{user_id: ^user_id, role: :owner, is_autocreated: true}] =
               team
               |> Repo.preload(:team_memberships)
               |> Map.fetch!(:team_memberships)
    end

    test "creates 'My Team' if user is a non-owner member on existing teams" do
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

    test "returns existing 'My Personal Sites' if user already owns one" do
      user = new_user(trial_expiry_date: ~D[2020-04-01])
      user_id = user.id
      existing_team = team_of(user)

      assert {:ok, team} = Teams.get_by_owner(user)

      assert team.id == existing_team.id
      assert Date.compare(team.trial_expiry_date, ~D[2020-04-01])
      assert team.name == "My Personal Sites"

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
end
