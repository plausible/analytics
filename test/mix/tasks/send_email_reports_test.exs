defmodule Mix.Tasks.EmailReportsTest do
  use Plausible.DataCase
  use Bamboo.Test
  alias Mix.Tasks.SendEmailReports

  describe "weekly reports" do
    test "sends weekly report on Monday 9am local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week |> Timex.shift(hours: 14) # 2pm UTC is 10am EST

      SendEmailReports.execute(time)

      assert_email_delivered_with(subject: "Weekly report for #{site.domain}", to: [nil: "user@email.com"])
    end

    test "does not send a report on Monday before 9am in local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week |> Timex.shift(hours: 12) # 12pm UTC is 8am EST

      SendEmailReports.execute(time)

      assert_no_emails_delivered()
    end

    test "does not send a report on Tuesday" do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week |> Timex.shift(days: 1, hours: 10)

      SendEmailReports.execute(time)

      assert_no_emails_delivered()
    end

    test "does not send the same report multiple times on the same week" do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week |> Timex.shift(hours: 10)

      SendEmailReports.execute(time)

      assert_email_delivered_with(subject: "Weekly report for #{site.domain}", to: [nil: "user@email.com"])

      SendEmailReports.execute(time)
      assert_no_emails_delivered()
    end
  end

  describe "monthly_reports" do
    test "sends monthly report on the 1st of the month after 9am local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      {:ok, time, _} = DateTime.from_iso8601("2019-04-01T14:00:00Z")

      SendEmailReports.execute(time)

      assert_email_delivered_with(subject: "March report for #{site.domain}", to: [nil: "user@email.com"])
    end

    test "does not send a report on the 1st of the month before 9am in local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_month |> Timex.shift(hours: 12) # 12pm UTC is 8am EST

      SendEmailReports.execute(time)

      assert_no_emails_delivered()
    end

    test "does not send a report on the 2nd of the month" do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_month |> Timex.shift(days: 1, hours: 10)

      SendEmailReports.execute(time)

      assert_no_emails_delivered()
    end

    test "does not send the same report multiple times on the same month" do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      {:ok, time, _} = DateTime.from_iso8601("2019-02-01T11:00:00Z")

      SendEmailReports.execute(time)

      assert_email_delivered_with(subject: "January report for #{site.domain}", to: [nil: "user@email.com"])

      SendEmailReports.execute(time)
      assert_no_emails_delivered()
    end
  end

  #  describe "when user does not have an active site" do
  #    test "does not send an email ever" do
  #      insert(:user, inserted_at: days_ago(15))
  #
  #      SendFeedbackEmails.execute()
  #
  #      assert_no_emails_delivered()
  #    end
  #  end
  #
  #  describe "when user has an active site" do
  #    test "sends an email if the user is more than 30 days old and logged on in the last week" do
  #      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(1))
  #      site = insert(:site, members: [user])
  #      insert(:pageview, hostname: site.domain)
  #
  #      SendFeedbackEmails.execute()
  #
  #      assert_email_delivered_with(subject: "Plausible feedback")
  #    end
  #
  #    test "sends the email only once" do
  #      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(1))
  #      site = insert(:site, members: [user])
  #      insert(:pageview, hostname: site.domain)
  #
  #      SendFeedbackEmails.execute()
  #      assert_email_delivered_with(subject: "Plausible feedback")
  #
  #      SendFeedbackEmails.execute()
  #      assert_no_emails_delivered()
  #    end
  #
  #    test "does not send if user has not logged in recently" do
  #      user = insert(:user, inserted_at: days_ago(31), last_seen: days_ago(15))
  #      site = insert(:site, members: [user])
  #      insert(:pageview, hostname: site.domain)
  #
  #      SendFeedbackEmails.execute()
  #
  #      assert_no_emails_delivered()
  #    end
  #
  #    test "does not send if user is less than a month old" do
  #      user = insert(:user, inserted_at: days_ago(15), last_seen: days_ago(1))
  #      site = insert(:site, members: [user])
  #      insert(:pageview, hostname: site.domain)
  #
  #      SendFeedbackEmails.execute()
  #
  #      assert_no_emails_delivered()
  #    end
  #  end
end
