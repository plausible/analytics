defmodule Plausible.Workers.SendSiteSetupEmailsTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo

  alias Plausible.Workers.SendSiteSetupEmails

  describe "when user has not managed to set up the site" do
    test "does not send an email 47 hours after site creation" do
      user = insert(:user)
      insert(:site, members: [user], inserted_at: hours_ago(47))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end

    test "sends a setup help email 48 hours after site has been created" do
      user = insert(:user)
      insert(:site, members: [user], inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup: Waiting for the first page views"
      )
    end

    test "does not send an email more than 72 hours after signup" do
      user = insert(:user)
      insert(:site, members: [user], inserted_at: hours_ago(73))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end
  end

  describe "when user has managed to set up their site" do
    test "sends the setup completed email as soon as possible" do
      user = insert(:user)

      site = insert(:site, members: [user])

      populate_stats(site, [build(:pageview)])

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible is now tracking your website stats"
      )
    end

    test "sends the setup completed email after the help email has been sent" do
      user = insert(:user)
      site = insert(:site, members: [user], inserted_at: hours_ago(49))

      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup: Waiting for the first page views"
      )

      create_pageviews([%{site: site}])
      perform_job(SendSiteSetupEmails, %{})

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible is now tracking your website stats"
      )
    end
  end

  describe "trial user who has not set up a website" do
    test "does not send an email before 48h have passed" do
      insert(:user, inserted_at: hours_ago(47))

      perform_job(SendSiteSetupEmails, %{})

      assert_no_emails_delivered()
    end

    test "sends the create site email after 48h" do
      user = insert(:user, inserted_at: hours_ago(49))

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
    |> Timex.shift(hours: -hours)
  end
end
