defmodule Plausible.Workers.SendCheckStatsEmailsTest do
  use Plausible.DataCase
  use Bamboo.Test

  defp perform() do
    Plausible.Workers.SendCheckStatsEmails.new(%{}) |> Oban.insert!()
    Oban.drain_queue(:check_stats_emails)
  end

  test "does not send an email before a week has passed" do
    user = insert(:user, inserted_at: days_ago(6), last_seen: days_ago(6))
    insert(:site, domain: "test-site.com", members: [user])

    perform()

    assert_no_emails_delivered()
  end

  test "does not send an email if the user has logged in recently" do
    user = insert(:user, inserted_at: days_ago(9), last_seen: days_ago(6))
    insert(:site, domain: "test-site.com", members: [user])

    perform()

    assert_no_emails_delivered()
  end

  test "does not send an email if the user has configured a weekly report" do
    user = insert(:user, inserted_at: days_ago(9), last_seen: days_ago(7))
    site = insert(:site, domain: "test-site.com", members: [user])
    insert(:weekly_report, site: site, recipients: ["user@email.com"])

    perform()

    assert_no_emails_delivered()
  end

  test "sends an email after a week of signup if the user hasn't logged in" do
    user = insert(:user, inserted_at: days_ago(8), last_seen: days_ago(8))
    insert(:site, domain: "test-site.com", members: [user])

    perform()

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Check your Plausible website stats"
    )
  end

  defp days_ago(days) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> Timex.shift(days: -days)
  end
end
