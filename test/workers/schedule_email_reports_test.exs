defmodule Plausible.Workers.ScheduleEmailReportsTest do
  use Plausible.DataCase
  use Oban.Testing, repo: Plausible.Repo
  alias Plausible.Workers.{ScheduleEmailReports, SendEmailReport}

  describe "weekly reports" do
    test "schedules weekly report on Monday 9am local timezone" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})

      assert_enqueued(
        worker: SendEmailReport,
        args: %{site_id: site.id, interval: "weekly"},
        scheduled_at: ScheduleEmailReports.monday_9am(site.timezone)
      )
    end

    test "does not schedule more than one weekly report at a time" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})
      perform_job(ScheduleEmailReports, %{})

      assert Enum.count(all_enqueued(worker: SendEmailReport)) == 1
    end

    test "does not schedule a weekly report for locked site" do
      site = insert(:site, locked: true, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})

      assert Enum.empty?(all_enqueued(worker: SendEmailReport))
    end

    test "schedules a new report as soon as a previous one is completed" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})
      Repo.update_all("oban_jobs", set: [state: "completed"])
      assert Enum.empty?(all_enqueued(worker: SendEmailReport))
      perform_job(ScheduleEmailReports, %{})
      assert Enum.count(all_enqueued(worker: SendEmailReport)) == 1
    end
  end

  describe "monthly_reports" do
    test "schedules monthly report on first of the next month at 9am local timezone" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})

      assert_enqueued(
        worker: SendEmailReport,
        args: %{site_id: site.id, interval: "monthly"},
        scheduled_at: ScheduleEmailReports.first_of_month_9am(site.timezone)
      )
    end

    test "does not schedule more than one monthly report at a time" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})
      perform_job(ScheduleEmailReports, %{})

      assert Enum.count(all_enqueued(worker: SendEmailReport)) == 1
    end

    test "does not schedule a monthly report for locked site" do
      site = insert(:site, locked: true, domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})

      assert Enum.empty?(all_enqueued(worker: SendEmailReport))
    end

    test "schedules a new report as soon as a previous one is completed" do
      site = insert(:site, domain: "test-site.com", timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])

      perform_job(ScheduleEmailReports, %{})
      Repo.update_all("oban_jobs", set: [state: "completed"])
      assert Enum.empty?(all_enqueued(worker: SendEmailReport))
      perform_job(ScheduleEmailReports, %{})
      assert Enum.count(all_enqueued(worker: SendEmailReport)) == 1
    end
  end
end
