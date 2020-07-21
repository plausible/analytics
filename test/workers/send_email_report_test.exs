defmodule Plausible.Workers.SendEmailReportTest do
  use Plausible.DataCase
  use Bamboo.Test
  alias Plausible.Workers.SendEmailReport

  defp perform(args) do
    SendEmailReport.new(args) |> Oban.insert!()
    Oban.drain_queue(:send_email_reports)
  end

  describe "weekly reports" do
    test "sends weekly report to all recipients" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com", "user2@email.com"])

      perform(%{"site_id" => site.id, "interval" => "weekly"})

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user@email.com"]
      )

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user2@email.com"]
      )
    end
  end

  describe "monthly_reports" do
    test "sends monthly report to all recipients" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com", "user2@email.com"])

      last_month =
        Timex.now(site.timezone)
        |> Timex.shift(months: -1)
        |> Timex.beginning_of_month()
        |> Timex.format!("{Mfull}")

      perform(%{"site_id" => site.id, "interval" => "monthly"})

      assert_email_delivered_with(
        subject: "#{last_month} report for #{site.domain}",
        to: [nil: "user@email.com"]
      )

      assert_email_delivered_with(
        subject: "#{last_month} report for #{site.domain}",
        to: [nil: "user2@email.com"]
      )
    end
  end
end
