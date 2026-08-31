defmodule Plausible.Workers.ExecuteTeamDeletionsTest do
  use Plausible.DataCase, async: true

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.Subscription
  alias Plausible.PendingStatsDeletion
  alias Plausible.Workers.ExecuteTeamDeletions

  @today ~D[2026-08-20]

  test "deletes the team's site and marks the schedule completed, keeping the team intact" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    schedule =
      insert(:team_deletion_schedule,
        team: team,
        status: :reminder_sent,
        deletion_date: @today
      )

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    refute Repo.reload(site)
    assert Repo.reload(team)
    assert Repo.reload!(schedule).status == :completed
  end

  test "deletes every site owned by the team" do
    owner = new_user()
    site_a = new_site(owner: owner)
    team = team_of(owner)
    site_b = new_site(team: team)

    insert(:team_deletion_schedule, team: team, status: :reminder_sent, deletion_date: @today)

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    refute Repo.reload(site_a)
    refute Repo.reload(site_b)
    assert Repo.reload(team)
  end

  test "does not touch the team's settings or subscription history" do
    owner = new_user()
    new_site(owner: owner)
    team = team_of(owner)

    subscription =
      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(@today, day: -400)
      )

    insert(:team_deletion_schedule, team: team, status: :reminder_sent, deletion_date: @today)

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    reloaded_team = Repo.reload(team)
    assert reloaded_team
    assert reloaded_team.name == team.name
    assert Repo.reload(subscription)
  end

  test "passes the schedule's category through as the pending stats deletion reason (expired_trial)" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    insert(:team_deletion_schedule,
      team: team,
      category: :expired_trial,
      status: :reminder_sent,
      deletion_date: @today
    )

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    assert Repo.get_by(PendingStatsDeletion, site_id: site.id).reason == :expired_trial
  end

  test "passes the schedule's category through as the pending stats deletion reason (churned_subscription)" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    insert(:team_deletion_schedule,
      team: team,
      category: :churned_subscription,
      status: :reminder_sent,
      deletion_date: @today
    )

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    assert Repo.get_by(PendingStatsDeletion, site_id: site.id).reason == :churned_subscription
  end

  test "does not touch a row whose deletion_date hasn't arrived" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    schedule =
      insert(:team_deletion_schedule,
        team: team,
        status: :reminder_sent,
        deletion_date: Date.shift(@today, day: 1)
      )

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    assert Repo.reload(team)
    assert Repo.reload(site)
    assert Repo.reload!(schedule).status == :reminder_sent
  end

  test "does not touch a row that hasn't had its reminder sent yet" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    schedule =
      insert(:team_deletion_schedule,
        team: team,
        status: :first_notice_sent,
        deletion_date: @today
      )

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    assert Repo.reload(team)
    assert Repo.reload(site)
    assert Repo.reload!(schedule).status == :first_notice_sent
  end

  test "cancels instead of deleting when the team has reactivated since the last scan" do
    owner = new_user()
    site = new_site(owner: owner)
    team = team_of(owner)

    schedule =
      insert(:team_deletion_schedule,
        team: team,
        status: :reminder_sent,
        deletion_date: @today
      )

    insert(:subscription, team: team, status: Subscription.Status.active())

    assert :ok = ExecuteTeamDeletions.perform(nil, @today)

    assert Repo.reload(team)
    assert Repo.reload(site)
    assert Repo.reload!(schedule).status == :cancelled
  end
end
