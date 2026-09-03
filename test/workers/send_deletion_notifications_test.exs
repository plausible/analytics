defmodule Plausible.Workers.SendDeletionNotificationsTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.Subscription
  alias Plausible.Workers.SendDeletionNotifications

  @today ~D[2026-08-20]

  describe "first notices" do
    test "sends the full notice email to owners and billing members" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner)

      insert(:team_membership, team: team, user: build(:user), role: :billing)

      insert(:subscription,
        team: team,
        status: Subscription.Status.deleted(),
        next_bill_date: Date.shift(@today, day: -400)
      )

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          category: :churned_subscription,
          status: :scheduled,
          first_notice_due_date: @today,
          deletion_date: ~D[2026-10-19]
        )

      SendDeletionNotifications.perform(nil, @today)

      team = Repo.preload(team, [:owners, :billing_members])
      recipients = team.owners ++ team.billing_members

      assert length(recipients) == 2

      for recipient <- recipients do
        assert_email_delivered_with(
          to: [{recipient.name, recipient.email}],
          subject: "Your Plausible dashboards and stats will be deleted in 30 days"
        )
      end

      assert Repo.reload!(schedule).status == :first_notice_sent
      assert Repo.reload!(schedule).first_notice_sent_at
    end

    test "finalizes a backlog row's deletion_date anchored to when the notice actually sends" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner) |> Plausible.Teams.Team.end_trial() |> Repo.update!()

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          category: :expired_trial,
          status: :scheduled,
          is_backlog: true,
          first_notice_due_date: @today,
          deletion_date: ~D[2024-01-01]
        )

      SendDeletionNotifications.perform(nil, @today)

      updated = Repo.reload!(schedule)
      assert updated.status == :first_notice_sent
      assert updated.deletion_date == Date.shift(@today, day: 30)
    end

    test "does not touch a row whose first_notice_due_date hasn't arrived" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner)

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          status: :scheduled,
          first_notice_due_date: Date.shift(@today, day: 1)
        )

      SendDeletionNotifications.perform(nil, @today)

      refute_email_delivered_with(
        subject: "Your Plausible dashboards and stats will be deleted in 30 days"
      )

      assert Repo.reload!(schedule).status == :scheduled
    end

    test "cancels instead of sending when the team has reactivated since the last scan" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner)

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          status: :scheduled,
          first_notice_due_date: @today
        )

      insert(:subscription, team: team, status: Subscription.Status.active())

      SendDeletionNotifications.perform(nil, @today)

      refute_email_delivered_with(
        subject: "Your Plausible dashboards and stats will be deleted in 30 days"
      )

      assert Repo.reload!(schedule).status == :cancelled
    end
  end

  describe "reminders" do
    test "sends the reminder email and advances status" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner) |> Plausible.Teams.Team.end_trial() |> Repo.update!()

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          status: :first_notice_sent,
          deletion_date: Date.shift(@today, day: 3)
        )

      SendDeletionNotifications.perform(nil, @today)

      assert_email_delivered_with(
        to: [{owner.name, owner.email}],
        subject: "Final notice: your Plausible dashboards and stats will be deleted in 5 days"
      )

      updated = Repo.reload!(schedule)
      assert updated.status == :reminder_sent
      assert updated.reminder_sent_at
    end

    test "does not touch a row whose deletion_date is still more than 5 days out" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner)

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          status: :first_notice_sent,
          deletion_date: Date.shift(@today, day: 6)
        )

      SendDeletionNotifications.perform(nil, @today)

      refute_email_delivered_with(
        subject: "Final notice: your Plausible dashboards and stats will be deleted in 5 days"
      )

      assert Repo.reload!(schedule).status == :first_notice_sent
    end

    test "cancels instead of sending when the team has reactivated since the last scan" do
      owner = new_user()
      new_site(owner: owner)
      team = team_of(owner)

      schedule =
        insert(:team_deletion_schedule,
          team: team,
          status: :first_notice_sent,
          deletion_date: Date.shift(@today, day: 3)
        )

      insert(:subscription, team: team, status: Subscription.Status.active())

      SendDeletionNotifications.perform(nil, @today)

      refute_email_delivered_with(
        subject: "Final notice: your Plausible dashboards and stats will be deleted in 5 days"
      )

      assert Repo.reload!(schedule).status == :cancelled
    end
  end

  describe "sites_summary/1" do
    test "returns every domain uncapped when the team has few sites" do
      owner = new_user()
      new_site(owner: owner)
      new_site(owner: owner)
      team = team_of(owner)

      summary = SendDeletionNotifications.sites_summary(team)

      assert length(summary.domains) == 2
      assert summary.more_count == 0
    end

    test "caps the domain list and reports how many more sites exist" do
      owner = new_user()

      for _ <- 1..13, do: new_site(owner: owner)

      team = team_of(owner)

      summary = SendDeletionNotifications.sites_summary(team)

      assert length(summary.domains) == 3
      assert summary.more_count == 10
    end
  end
end
