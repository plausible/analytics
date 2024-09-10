defmodule Plausible.Workers.ScheduleEmailReports do
  use Plausible.Repo
  use Oban.Worker, queue: :schedule_email_reports
  alias Plausible.Workers.SendEmailReport
  require Logger

  @impl Oban.Worker
  @doc """
    Email reports should be sent on Monday at 9am according to the timezone
  of a site. This job runs every day at midnight to ensure that all sites
  have a scheduled job for email reports.
  """
  def perform(_job) do
    schedule_weekly_emails()
    schedule_monthly_emails()
  end

  defp schedule_weekly_emails() do
    weekly_jobs =
      from(
        j in Oban.Job,
        where:
          j.worker == "Plausible.Workers.SendEmailReport" and
            fragment("(? ->> 'interval')", j.args) == "weekly"
      )

    sites =
      Repo.all(
        from s in Plausible.Site,
          join: wr in Plausible.Site.WeeklyReport,
          on: wr.site_id == s.id,
          left_join: job in subquery(weekly_jobs),
          on:
            fragment("(? -> 'site_id')::int", job.args) == s.id and
              job.state not in ["completed", "discarded"],
          where: is_nil(job),
          where: not s.locked,
          preload: [weekly_report: wr]
      )

    for site <- sites do
      SendEmailReport.new(%{site_id: site.id, interval: "weekly"},
        scheduled_at: monday_9am(site.timezone)
      )
      |> Oban.insert!()
    end

    :ok
  end

  def monday_9am(timezone) do
    DateTime.now!(timezone)
    |> DateTime.shift(week: 1)
    |> Timex.beginning_of_week()
    |> DateTime.shift(hour: 9)
  end

  defp schedule_monthly_emails() do
    monthly_jobs =
      from(
        j in Oban.Job,
        where:
          j.worker == "Plausible.Workers.SendEmailReport" and
            fragment("(? ->> 'interval')", j.args) == "monthly"
      )

    sites =
      Repo.all(
        from s in Plausible.Site,
          join: mr in Plausible.Site.MonthlyReport,
          on: mr.site_id == s.id,
          left_join: job in subquery(monthly_jobs),
          on:
            fragment("(? -> 'site_id')::int", job.args) == s.id and
              job.state not in ["completed", "discarded"],
          where: is_nil(job),
          where: not s.locked,
          preload: [monthly_report: mr]
      )

    for site <- sites do
      SendEmailReport.new(%{site_id: site.id, interval: "monthly"},
        scheduled_at: first_of_month_9am(site.timezone)
      )
      |> Oban.insert!()
    end

    :ok
  end

  def first_of_month_9am(timezone) do
    DateTime.now!(timezone)
    |> DateTime.shift(month: 1)
    |> Timex.beginning_of_month()
    |> DateTime.shift(hour: 9)
  end
end
