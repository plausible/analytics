defmodule Plausible.Workers.SendEmailReportTest do
  use Plausible.DataCase
  use Bamboo.Test
  use Plausible.Teams.Test
  use Oban.Testing, repo: Plausible.Repo
  import Plausible.Test.Support.HTML
  alias Plausible.Workers.SendEmailReport

  @green "#15803d"
  @red "#b91c1c"

  describe "weekly reports" do
    test "sends weekly report to all recipients" do
      site = new_site(domain: "test-site.com", timezone: "US/Eastern")
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

    test "does not crash when weekly report has been deleted since scheduling job" do
      site = new_site(domain: "test-site.com", timezone: "US/Eastern")

      assert :discard =
               perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})
    end

    test "calculates timezone correctly" do
      site =
        new_site(timezone: "US/Eastern")

      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      now = DateTime.now!(site.timezone)
      last_monday = DateTime.shift(now, week: -1) |> Plausible.Times.beginning_of_week()
      last_sunday = DateTime.shift(now, week: -1) |> Plausible.Times.end_of_week()
      sunday_before_last = DateTime.shift(last_monday, minute: -1)
      this_monday = Plausible.Times.beginning_of_week(now)

      populate_stats(site, [
        # Sunday before last, not counted
        build(:pageview, timestamp: DateTime.shift_zone!(sunday_before_last, "UTC")),
        # Sunday before last, not counted
        build(:pageview, timestamp: DateTime.shift_zone!(sunday_before_last, "UTC")),
        # Last monday, counted
        build(:pageview, timestamp: DateTime.shift_zone!(last_monday, "UTC")),
        # Last sunday, counted
        build(:pageview, timestamp: DateTime.shift_zone!(last_sunday, "UTC")),
        # This monday, not counted
        build(:pageview, timestamp: DateTime.shift_zone!(this_monday, "UTC")),
        # This monday, not counted
        build(:pageview, timestamp: DateTime.shift_zone!(this_monday, "UTC"))
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      # Should find 2 visiors
      assert text_of_element(html_body, ".page-count") == "2"
    end

    test "includes the correct stats" do
      now = NaiveDateTime.utc_now(:second)
      site = new_site(domain: "test-site.com", inserted_at: NaiveDateTime.shift(now, day: -8))
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          timestamp: NaiveDateTime.shift(now, day: -7),
          referrer_source: "Google"
        ),
        build(:pageview, user_id: 123, timestamp: NaiveDateTime.shift(now, day: -7)),
        build(:pageview, timestamp: NaiveDateTime.shift(now, day: -7))
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      assert text_of_element(html_body, ".visitors") == "2"
      assert text_of_element(html_body, ".pageviews") == "3"
      assert text_of_element(html_body, ".referrer-name") == "Google"
      assert text_of_element(html_body, ".referrer-count") == "1"
      assert text_of_element(html_body, ".page-name") == "/"
      assert text_of_element(html_body, ".page-count") == "2"
    end

    test "renders correct signs (+/-) and trend colors for positive percentage changes" do
      now = NaiveDateTime.utc_now(:second)
      week_ago = now |> NaiveDateTime.shift(day: -7)
      two_weeks_ago = now |> NaiveDateTime.shift(day: -14)

      site = new_site(inserted_at: NaiveDateTime.shift(now, day: -15))
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      populate_stats(site, [
        build(:pageview, timestamp: two_weeks_ago),
        build(:pageview, user_id: 1, timestamp: week_ago),
        build(:pageview, user_id: 2, timestamp: week_ago),
        build(:pageview, user_id: 2, timestamp: week_ago)
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      visitors_change_container = find(html_body, ".change-visitors div")
      assert text(visitors_change_container) == "+100%"
      assert text_of_attr(visitors_change_container, "style") =~ @green

      pageviews_change_container = find(html_body, ".change-pageviews div")
      assert text(pageviews_change_container) == "+200%"
      assert text_of_attr(pageviews_change_container, "style") =~ @green

      bounce_rate_change_container = find(html_body, ".change-bounce-rate div")
      assert text(bounce_rate_change_container) == "-50%"
      assert text_of_attr(bounce_rate_change_container, "style") =~ @green
    end

    test "renders correct signs (+/-) and trend colors for negative percentage changes" do
      now = NaiveDateTime.utc_now(:second)
      week_ago = now |> NaiveDateTime.shift(day: -7)
      two_weeks_ago = now |> NaiveDateTime.shift(day: -14)

      site = new_site(inserted_at: NaiveDateTime.shift(now, day: -15))
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: two_weeks_ago),
        build(:pageview, user_id: 2, timestamp: two_weeks_ago),
        build(:pageview, user_id: 2, timestamp: two_weeks_ago),
        build(:pageview, timestamp: week_ago)
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      visitors_change_container = find(html_body, ".change-visitors div")
      assert text(visitors_change_container) == "-50%"
      assert text_of_attr(visitors_change_container, "style") =~ @red

      pageviews_change_container = find(html_body, ".change-pageviews div")
      assert text(pageviews_change_container) == "-67%"
      assert text_of_attr(pageviews_change_container, "style") =~ @red

      bounce_rate_change_container = find(html_body, ".change-bounce-rate div")
      assert text(bounce_rate_change_container) == "+50%"
      assert text_of_attr(bounce_rate_change_container, "style") =~ @red
    end

    test "renders 0% changes with a green color and without a sign" do
      now = NaiveDateTime.utc_now(:second)
      week_ago = now |> NaiveDateTime.shift(day: -7)
      two_weeks_ago = now |> NaiveDateTime.shift(day: -14)

      site = new_site(inserted_at: NaiveDateTime.shift(now, day: -15))
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      populate_stats(site, [
        build(:pageview, timestamp: two_weeks_ago),
        build(:pageview, timestamp: week_ago)
      ])

      perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "weekly"})

      assert_delivered_email_matches(%{
        to: [nil: "user@email.com"],
        html_body: html_body
      })

      visitors_change_container = find(html_body, ".change-visitors div")
      assert text(visitors_change_container) == "0%"
      assert text_of_attr(visitors_change_container, "style") =~ @green

      pageviews_change_container = find(html_body, ".change-pageviews div")
      assert text(pageviews_change_container) == "0%"
      assert text_of_attr(pageviews_change_container, "style") =~ @green

      bounce_rate_change_container = find(html_body, ".change-bounce-rate div")
      assert text(bounce_rate_change_container) == "0%"
      assert text_of_attr(bounce_rate_change_container, "style") =~ @green
    end
  end

  describe "monthly_reports" do
    test "sends monthly report to all recipients" do
      site = new_site(domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com", "user2@email.com"])

      last_month =
        DateTime.now!(site.timezone)
        |> DateTime.shift(month: -1)
        |> Plausible.Times.beginning_of_month()
        |> Calendar.strftime("%B")

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

    test "does not crash when monthly report has been deleted since scheduling job" do
      site = new_site(domain: "test-site.com", timezone: "US/Eastern")

      assert :discard =
               perform_job(SendEmailReport, %{"site_id" => site.id, "interval" => "monthly"})
    end
  end
end
