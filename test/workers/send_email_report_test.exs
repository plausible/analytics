defmodule Plausible.Workers.SendEmailReportTest do
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

    test "does not crash for deleted sites" do
      assert :discard =
               perform_job(SendEmailReport, %{"site_id" => 28_378_237, "interval" => "weekly"})
    end

    test "calculates timezone correctly" do
      site =
        insert(:site,
          timezone: "US/Eastern"
        )

      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      now = Timex.now(site.timezone)
      last_monday = Timex.shift(now, weeks: -1) |> Timex.beginning_of_week()
      last_sunday = Timex.shift(now, weeks: -1) |> Timex.end_of_week()
      sunday_before_last = Timex.shift(last_monday, minutes: -1)
      this_monday = Timex.beginning_of_week(now)

      create_pageviews([
        # Sunday before last, not counted
        %{site: site, timestamp: Timezone.convert(sunday_before_last, "UTC")},
        # Sunday before last, not counted
        %{site: site, timestamp: Timezone.convert(sunday_before_last, "UTC")},
        # Last monday, counted
        %{site: site, timestamp: Timezone.convert(last_monday, "UTC")},
        # Last sunday, counted
        %{site: site, timestamp: Timezone.convert(last_sunday, "UTC")},
        # This monday, not counted
        %{site: site, timestamp: Timezone.convert(this_monday, "UTC")},
        # This monday, not counted
        %{site: site, timestamp: Timezone.convert(this_monday, "UTC")}
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      # Should find 2 visiors

      page_count = html_body |> Floki.find(".page-count") |> Floki.text() |> String.trim()
      assert page_count == "2"
    end

    test "includes the correct stats" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      site = insert(:site, domain: "test-site.com", inserted_at: Timex.shift(now, days: -8))
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

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

      visitors =
        Floki.find(document, ".visitors")
        |> List.first()
        |> Floki.text()
        |> String.trim()

      assert visitors == "2"

      pageviews = Floki.find(document, ".pageviews") |> Floki.text() |> String.trim()
      assert pageviews == "3"

      referrer_name =
        document |> Floki.find(".referrer-name") |> List.first() |> Floki.text() |> String.trim()

      referrer_count =
        document |> Floki.find(".referrer-count") |> List.first() |> Floki.text() |> String.trim()

      assert referrer_name == "Google"
      assert referrer_count == "1"

      page_name = document |> Floki.find(".page-name") |> Floki.text() |> String.trim()
      page_count = document |> Floki.find(".page-count") |> Floki.text() |> String.trim()

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
