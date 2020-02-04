defmodule Mix.Tasks.SendFeedbackEmailsTest do
  use Plausible.DataCase
  use Bamboo.Test
  alias Mix.Tasks.SendFeedbackEmails

  describe "when user does not have an active site" do
    test "does not send an email ever" do
      insert(:user, inserted_at: days_ago(15))

      SendFeedbackEmails.execute()

      assert_no_emails_delivered()
    end
  end

  describe "when user has an active site" do
    test "sends an email if the user is more than 30 days old and logged on in the last week" do
      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(1))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      SendFeedbackEmails.execute()

      assert_email_delivered_with(subject: "Plausible feedback")
    end

    test "sends the email only once" do
      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(1))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      SendFeedbackEmails.execute()
      assert_email_delivered_with(subject: "Plausible feedback")

      SendFeedbackEmails.execute()
      assert_no_emails_delivered()
    end

    test "does not send if user has not logged in recently" do
      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(15))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      SendFeedbackEmails.execute()

      assert_no_emails_delivered()
    end

    test "does not send if user is less than a month old" do
      user = insert(:user, inserted_at: days_ago(15), last_seen: days_ago(1))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      SendFeedbackEmails.execute()

      assert_no_emails_delivered()
    end
  end

  defp days_ago(days) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> Timex.shift(days: -days)
  end
end
