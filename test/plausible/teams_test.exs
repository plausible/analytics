defmodule Plausible.TeamsTest do
  use Plausible.DataCase, async: true

  use Plausible.Teams.Test

  alias Plausible.Teams
  alias Plausible.Repo

  describe "trial_days_left" do
    test "is 30 days for new signup" do
      site = new_site()

      assert Teams.trial_days_left(site.team) == 30
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
