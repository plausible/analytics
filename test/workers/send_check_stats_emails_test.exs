defmodule Plausible.Workers.SendCheckStatsEmailsTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo
  use Bamboo.Test
  use Plausible.Teams.Test

  alias Plausible.Workers.SendCheckStatsEmails

  test "does not send an email before a week has passed" do
    user = new_user(inserted_at: days_ago(6), last_seen: days_ago(6))
    new_site(domain: "test-site.com", owner: user)

    perform_job(SendCheckStatsEmails, %{})

    assert_no_emails_delivered()
  end

  test "does not send an email if the user has logged in recently" do
    user = new_user(inserted_at: days_ago(9), last_seen: days_ago(6))
    new_site(domain: "test-site.com", owner: user)

    perform_job(SendCheckStatsEmails, %{})

    assert_no_emails_delivered()
  end

  test "does not send an email if the user has configured a weekly report" do
    user = new_user(inserted_at: days_ago(9), last_seen: days_ago(7))
    site = new_site(domain: "test-site.com", owner: user)

    populate_stats(site, [build(:pageview)])
    insert(:weekly_report, site: site, recipients: ["user@email.com"])

    perform_job(SendCheckStatsEmails, %{})

    assert_no_emails_delivered()
  end

  test "sends an email after a week of signup if the user hasn't logged in" do
    user = new_user(inserted_at: days_ago(8), last_seen: days_ago(8))
    site = new_site(domain: "test-site.com", owner: user)
    populate_stats(site, [build(:pageview)])

    perform_job(SendCheckStatsEmails, %{})

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Check your Plausible website stats"
    )
  end

  defp days_ago(days) do
    NaiveDateTime.utc_now(:second)
    |> NaiveDateTime.shift(day: -days)
  end
end
