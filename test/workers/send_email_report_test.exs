defmodule Plausible.Workers.SendEmailReportTest do
  import Plausible.TestUtils
  use Plausible.DataCase
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo
  alias Plausible.Workers.SendEmailReport
  alias Timex.Timezone

  describe "weekly reports" do
    test "sends weekly report to all recipients" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com", "user2@email.com"])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user@email.com"]
      )

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user2@email.com"]
      )
    end

    test "calculates timezone correctly" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      now = Timex.now(site.timezone)
      last_monday = Timex.shift(now, weeks: -1) |> Timex.beginning_of_week()
      last_sunday = Timex.shift(now, weeks: -1) |> Timex.end_of_week()
      sunday_before_last = Timex.shift(last_monday, minutes: -1)
      this_monday = Timex.beginning_of_week(now)

      create_pageviews([
        # Sunday before last, not counted
        %{domain: site.domain, timestamp: Timezone.convert(sunday_before_last, "UTC")},
        # Sunday before last, not counted
        %{domain: site.domain, timestamp: Timezone.convert(sunday_before_last, "UTC")},
        # Last monday, counted
        %{domain: site.domain, timestamp: Timezone.convert(last_monday, "UTC")},
        # Last sunday, counted
        %{domain: site.domain, timestamp: Timezone.convert(last_sunday, "UTC")},
        # This monday, not counted
        %{domain: site.domain, timestamp: Timezone.convert(this_monday, "UTC")},
        # This monday, not counted
        %{domain: site.domain, timestamp: Timezone.convert(this_monday, "UTC")}
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      # Should find 2 visiors
      assert html_body =~
               ~s(<span id="visitors" style="line-height: 24px; font-size: 20px;">2</span>)
    end

    test "includes the correct stats" do
      site = insert(:site, domain: "test-site.com")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          user_id: 123,
          timestamp: Timex.shift(now, days: -7)
        ),
        build(:pageview, user_id: 123, timestamp: Timex.shift(now, days: -7)),
        build(:pageview, timestamp: Timex.shift(now, days: -7))
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      {:ok, document} = Floki.parse_document(html_body)

      visitors = Floki.find(document, "#visitors") |> Floki.text()
      assert visitors == "2"

      pageviews = Floki.find(document, "#pageviews") |> Floki.text()
      assert pageviews == "3"

      referrer = Floki.find(document, ".referrer") |> List.first()
      referrer_name = referrer |> Floki.find("#referrer-name") |> Floki.text()
      referrer_count = referrer |> Floki.find("#referrer-count") |> Floki.text()

      assert referrer_name == "Google"
      assert referrer_count == "1"

      page = Floki.find(document, ".page") |> List.first()
      page_name = page |> Floki.find("#page-name") |> Floki.text()
      page_count = page |> Floki.find("#page-count") |> Floki.text()

      assert page_name == "/"
      assert page_count == "2"
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

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "monthly"})

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
