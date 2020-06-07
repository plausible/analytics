defmodule Plausible.Workers.SendTrialNotificationsTest do
  use Plausible.DataCase
  use Bamboo.Test

  defp perform() do
    Plausible.Workers.SendTrialNotifications.new(%{}) |> Oban.insert!()
    Oban.drain_queue(:trial_notification_emails)
  end

  test "does not send a notification if user didn't set up their site" do
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -14))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -29))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -30))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -31))

    perform()

    assert_no_emails_delivered()
  end

  describe "with site and pageviews" do
    test "sends a reminder 7 days before trial ends (16 days after user signed up)" do
      user = insert(:user, trial_expiry_date: Timex.now |> Timex.shift(days: 7))
      insert(:site, domain: "test-site.com", members: [user])

      perform()

      assert_delivered_email(PlausibleWeb.Email.trial_one_week_reminder(user))
    end

    test "sends an upgrade email the day before the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.now |> Timex.shift(days: 1))
      insert(:site, domain: "test-site.com", members: [user])

      perform()

      assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", 3))
    end

    test "sends an upgrade email the day the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.today())
      insert(:site, domain: "test-site.com", members: [user])

      perform()

      assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "today", 3))
    end

    test "sends a trial over email the day after the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))
      insert(:site, domain: "test-site.com", members: [user])

      perform()

      assert_delivered_email(PlausibleWeb.Email.trial_over_email(user))
    end

    test "does not send a notification if user has a subscription" do
      user = insert(:user, trial_expiry_date: Timex.now |> Timex.shift(days: 7))
      insert(:site, domain: "test-site.com", members: [user])
      insert(:subscription, user: user)

      perform()

      assert_no_emails_delivered()
    end
  end
end
