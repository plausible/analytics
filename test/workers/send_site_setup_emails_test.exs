defmodule Plausible.Workers.SendSiteSetupEmailsTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo

  alias Plausible.Workers.SendSiteSetupEmails

  describe "when user has not managed to set up the site" do
    test "does not send an email 47 hours after site creation" do
      user = new_user()
      new_site(owner: user, inserted_at: hours_ago(47))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end

    test "sends a setup help email 48 hours after site has been created" do
      user = new_user()
      new_site(owner: user, inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup: Waiting for the first page views"
      )
    end

    test "does not send an email more than 72 hours after signup" do
      user = new_user()
      new_site(owner: user, inserted_at: hours_ago(73))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end
  end

  describe "when user has managed to set up their site" do
    test "sends the setup completed email as soon as possible" do
      user = new_user()
      site = new_site(owner: user)

      populate_stats(site, [build(:pageview)])

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible is now tracking your website stats"
      )
    end

    test "sends the setup completed email after the help email has been sent" do
      user = new_user()
      site = new_site(owner: user, inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup: Waiting for the first page views"
      )

      populate_stats(site, [
        build(:pageview)
      ])

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible is now tracking your website stats"
      )
    end

    test "do not send the setup help email for consolidated site" do
      user = new_user()
      site = new_site(owner: user)

      populate_stats(site, [build(:pageview)])

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible is now tracking your website stats"
      )

      new_site(owner: user, consolidated: true, inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end

    test "do not send the setup success email for consolidated website" do
      user = new_user()

      # for test purposes, set stats_start_date for a consolidated site
      new_site(owner: user, consolidated: true, stats_start_date: Date.utc_today())

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end
  end

  describe "trial user who has not set up a website" do
    test "does not send an email before 48h have passed" do
      new_user(inserted_at: hours_ago(47))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end

    test "sends the create site email after 48h" do
      user = new_user(inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup: Add your website details"
      )
    end
  end

  defp hours_ago(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.shift(hour: -hours)
  end
end
