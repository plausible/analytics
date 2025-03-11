defmodule Plausible.Workers.SendTrialNotificationsTest do
  use Plausible.DataCase
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo
  use Plausible.Teams.Test
  alias Plausible.Workers.SendTrialNotifications

  test "does not send a notification if user didn't create a site" do
    new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 7))
    new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 1))
    new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 0))
    new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  test "does not send a notification if user does not have a trial" do
    user = new_user()
    new_site(owner: user)
    user |> team_of() |> Ecto.Changeset.change(trial_expiry_date: nil) |> Plausible.Repo.update!()

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  test "does not send a notification if user created a site but there are no pageviews" do
    user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 7))
    new_site(owner: user)

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  test "does not send a notification if user is a collaborator on sites but not an owner" do
    user = new_user(trial_expiry_date: Date.utc_today())
    site = new_site()
    add_guest(site, user: user, role: :editor)

    populate_stats(site, [build(:pageview)])

    perform_job(SendTrialNotifications, %{})

    assert_no_emails_delivered()
  end

  describe "with site and pageviews" do
    test "sends a reminder 7 days before trial ends (16 days after user signed up)" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 7))
      site = new_site(owner: user)
      populate_stats(site, [build(:pageview)])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_one_week_reminder(user))
    end

    test "includes billing member in recipients" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 7))
      site = new_site(owner: user)
      team = team_of(user)
      billing_member = new_user()
      add_member(team, user: billing_member, role: :billing)

      populate_stats(site, [build(:pageview)])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_one_week_reminder(user))
      assert_delivered_email(PlausibleWeb.Email.trial_one_week_reminder(billing_member))
    end

    test "sends an upgrade email the day before the trial ends" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 1))
      site = new_site(owner: user)
      usage = %{total: 3, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      populate_stats(site, [
        build(:pageview),
        build(:pageview),
        build(:pageview)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(
        PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", usage, suggested_plan)
      )
    end

    test "sends an upgrade email the day the trial ends" do
      user = new_user(trial_expiry_date: Date.utc_today())
      site = new_site(owner: user)
      usage = %{total: 3, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      populate_stats(site, [
        build(:pageview),
        build(:pageview),
        build(:pageview)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(
        PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      )
    end

    test "does not include custom event note if user has not used custom events" do
      user = new_user(trial_expiry_date: Date.utc_today())
      site = new_site(owner: user)
      usage = %{total: 9_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)

      assert email.html_body =~
               "In the last month, your account has used 9,000 billable pageviews."
    end

    test "includes custom event note if user has used custom events" do
      user = new_user(trial_expiry_date: Date.utc_today())
      site = new_site(owner: user)
      usage = %{total: 9_100, custom_events: 100}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)

      assert email.html_body =~
               "In the last month, your account has used 9,100 billable pageviews and custom events in total."
    end

    test "sends a trial over email the day after the trial ends" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
      site = new_site(owner: user)

      populate_stats(site, [
        build(:pageview),
        build(:pageview),
        build(:pageview)
      ])

      perform_job(SendTrialNotifications, %{})

      assert_delivered_email(PlausibleWeb.Email.trial_over_email(user))
    end

    test "does not send a notification if user has a subscription" do
      user = new_user(trial_expiry_date: Date.utc_today() |> Date.shift(day: 7))
      site = new_site(owner: user)

      populate_stats(site, [
        build(:pageview),
        build(:pageview),
        build(:pageview)
      ])

      subscribe_to_growth_plan(user)

      perform_job(SendTrialNotifications, %{})

      assert_no_emails_delivered()
    end
  end

  describe "Suggested plans" do
    test "suggests 10k/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 9_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 10k/mo plan."
    end

    test "suggests 100k/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 90_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 100k/mo plan."
    end

    test "suggests 200k/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 180_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 200k/mo plan."
    end

    test "suggests 500k/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 450_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 500k/mo plan."
    end

    test "suggests 1m/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 900_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 1M/mo plan."
    end

    test "suggests 2m/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 1_800_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 2M/mo plan."
    end

    test "suggests 5m/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 4_500_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 5M/mo plan."
    end

    test "suggests 10m/mo plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 9_000_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "we recommend you select a 10M/mo plan."
    end

    test "does not suggest a plan above that" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 20_000_000, custom_events: 0}
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "please reply back to this email to get a quote for your volume"
    end

    test "does not suggest a plan when user is switching to an enterprise plan" do
      user = new_user()
      site = new_site(owner: user)
      usage = %{total: 10_000, custom_events: 0}
      subscribe_to_enterprise_plan(user, paddle_plan_id: "enterprise-plan-id")
      suggested_plan = Plausible.Billing.Plans.suggest(site.team, usage.total)

      email = PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      assert email.html_body =~ "please reply back to this email to get a quote for your volume"
    end
  end
end
