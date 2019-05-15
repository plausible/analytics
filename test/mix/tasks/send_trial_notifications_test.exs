defmodule Mix.Tasks.SendTrialNotificationsTest do
  use Plausible.DataCase
  use Bamboo.Test

  test "sends a reminder 14 days before trial ends" do
    user = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -14))

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

  test "sends an upgrade email the day the trial ends" do
    user = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -30))
    site = insert(:site, members: [user])
    insert(:pageview, hostname: site.domain)

    Mix.Tasks.SendTrialNotifications.execute()

    assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "today", 1))
  end

  test "sends a trial over email on the day after the trial ends" do
    user = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -31))

    Mix.Tasks.SendTrialNotifications.execute()

    assert_delivered_email(PlausibleWeb.Email.trial_over_email(user))
  end

  test "does not send a notification if user has a subscription" do
    user1 = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -14))
    user2 = insert(:user, inserted_at: Timex.now |> Timex.shift(days: -29))
    insert(:subscription, user: user1)
    insert(:subscription, user: user2)

    Mix.Tasks.SendTrialNotifications.execute()

    assert_no_emails_delivered()
  end

end
