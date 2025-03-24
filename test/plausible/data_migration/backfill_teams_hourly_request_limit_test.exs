defmodule Plausible.DataMigration.BackfillTeamsHourlyRequestLimitTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  import ExUnit.CaptureIO

  alias Plausible.DataMigration.BackfillTeamsHourlyRequestLimit

  alias Plausible.Repo

  describe "run/1" do
    test "runs for empty dataset" do
      dry_run_output =
        capture_io(fn ->
          assert :ok = BackfillTeamsHourlyRequestLimit.run()
        end)

      assert dry_run_output =~ "DRY RUN: true"
      assert dry_run_output =~ "About to update 0 teams with active enterprise plans"
      assert dry_run_output =~ "Done!"

      real_run_output =
        capture_io(fn ->
          assert :ok = BackfillTeamsHourlyRequestLimit.run(dry_run?: false)
        end)

      assert real_run_output =~ "DRY RUN: false"
      assert real_run_output =~ "About to update 0 teams with active enterprise plans"
      assert real_run_output =~ "Done!"
    end

    test "updates teams with active subscriptions and matching enterprise plans" do
      user1 =
        new_user() |> subscribe_to_enterprise_plan(hourly_api_request_limit: 5000)

      team1 = team_of(user1)

      user2 =
        new_user()
        |> subscribe_to_enterprise_plan(hourly_api_request_limit: 5000, subscription?: false)

      team2 = team_of(user2)

      user3 = new_user() |> subscribe_to_growth_plan()

      team3 = team_of(user3)

      user4 = new_user(trial_expiry_date: Date.add(Date.utc_today(), 30))

      team4 = team_of(user4)

      real_run_output =
        capture_io(fn ->
          assert :ok = BackfillTeamsHourlyRequestLimit.run(dry_run?: false)
        end)

      assert real_run_output =~ "DRY RUN: false"
      assert real_run_output =~ "About to update 1 teams with active enterprise plans"
      assert real_run_output =~ "Done!"

      assert Repo.reload(team1).hourly_api_request_limit == 5000
      assert Repo.reload(team2).hourly_api_request_limit == 600
      assert Repo.reload(team3).hourly_api_request_limit == 600
      assert Repo.reload(team4).hourly_api_request_limit == 600
    end
  end
end
