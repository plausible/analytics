defmodule Plausible.Workers.SendTrialNotificationsTest do
  use Plausible.DataCase
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo
  import Plausible.TestUtils
  alias Plausible.Workers.SendTrialNotifications

  test "does not send a notification if user didn't create a site" do
    insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 7))
    insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 1))
    insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 0))
    insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: -1))

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  test "does not send a notification if user created a site but there are no pageviews" do
    user = insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 7))
    insert(:site, members: [user])

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  test "does not send a notification if user is a collaborator on sites but not an owner" do
    user = insert(:user, trial_expiry_date: Timex.now())

    site =
      insert(:site,
        memberships: [
          build(:site_membership, user: user, role: :admin)
        ]
      )

    populate_stats(site, [build(:pageview, domain: site.domain)])

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  describe "with site and pageviews" do
    test "sends a reminder 7 days before trial ends (16 days after user signed up)" do
      user = insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 7))
      site = insert(:site, members: [user])
      populate_stats(site, [build(:pageview, domain: site.domain)])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_one_week_reminder(user))
    end

    test "sends an upgrade email the day before the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", {3, 0}))
    end

    test "sends an upgrade email the day the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.today())
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_upgrade_email(user, "today", {3, 0}))
    end

    test "does not include custom event note if user has not used custom events" do
      user = insert(:user, trial_expiry_date: Timex.today())

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {9_000, 0})

      assert email.html_body =~
               "In the last month, your account has used 9,000 billable pageviews."
    end

    test "includes custom event note if user has used custom events" do
      user = insert(:user, trial_expiry_date: Timex.today())

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {9_000, 100})

      assert email.html_body =~
               "In the last month, your account has used 9,100 billable pageviews and custom events in total."
    end

    test "sends a trial over email the day after the trial ends" do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_over_email(user))
    end

    test "does not send a notification if user has a subscription" do
      user = insert(:user, trial_expiry_date: Timex.now() |> Timex.shift(days: 7))
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain),
        build(:pageview, domain: site.domain)
      ])

      insert(:subscription, user: user)

      perform_job(SendTrialNotifications, %{})

      assert_no_emails_delivered()
    end
  end

  describe "Suggested plans" do
    test "suggests 10k/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {9_000, 0})
      assert email.html_body =~ "we recommend you select the 10k/mo plan."
    end

    test "suggests 100k/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {90_000, 0})
      assert email.html_body =~ "we recommend you select the 100k/mo plan."
    end

    test "suggests 200k/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {180_000, 0})
      assert email.html_body =~ "we recommend you select the 200k/mo plan."
    end

    test "suggests 500k/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {450_000, 0})
      assert email.html_body =~ "we recommend you select the 500k/mo plan."
    end

    test "suggests 1m/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {900_000, 0})
      assert email.html_body =~ "we recommend you select the 1M/mo plan."
    end

    test "suggests 2m/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {1_800_000, 0})
      assert email.html_body =~ "we recommend you select the 2M/mo plan."
    end

    test "suggests 5m/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {4_500_000, 0})
      assert email.html_body =~ "we recommend you select the 5M/mo plan."
    end

    test "suggests 10m/mo plan" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {9_000_000, 0})
      assert email.html_body =~ "we recommend you select the 10M/mo plan."
    end

    test "does not suggest a plan above that" do
      user = insert(:user)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", {20_000_000, 0})
      assert email.html_body =~ "please reply back to this email to get a quote for your volume"
    end
  end
end
