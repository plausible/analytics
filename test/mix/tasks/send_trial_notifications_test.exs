defmodule Mix.Tasks.SendTrialNotificationsTest do
  use Plausible.DataCase
  use Bamboo.Test

  test "does not send a notification if user didn't set up their site" do
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -14))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -29))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -30))
    insert(:user, inserted_at: Timex.now |> Timex.shift(days: -31))

    Mix.Tasks.SendTrialNotifications.execute()

    assert_no_emails_delivered()
  end

  describe "with site and pageviews" do
    test "sends a reminder 14 days before trial ends (16 days after user signed up)" do
      user = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -16))
      site = insert(:site, members: [user])
      insert(:pageview, hostname: site.domain)

      Mix.Tasks.SendTrialNotifications.execute()

      assert_delivered_email(PlausibleWeb.Email.trial_two_week_reminder(user))
    end

    test "sends an upgrade email the day before the trial ends" do
      user = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -29))
      site = insert(:site, members: [user])
      insert(:pageview, hostname: site.domain)

      Mix.Tasks.SendTrialNotifications.execute()

      assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", 1))
    end

    test "does not send a notification if user has a subscription" do
      user1 = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -14))
      site1 = insert(:site, members: [user1])
      insert(:pageview, hostname: site1.domain)
      user2 = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -29))
      site2 = insert(:site, members: [user2])
      insert(:pageview, hostname: site2.domain)

      insert(:subscription, user: user1)
      insert(:subscription, user: user2)

      Mix.Tasks.SendTrialNotifications.execute()

      assert_no_emails_delivered()
    end
  end
end
