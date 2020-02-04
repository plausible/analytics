defmodule Mix.Tasks.SendEmailReports do
  use Mix.Task
  use Plausible.Repo
  require Logger
  alias Plausible.Stats

  def run(_args) do
    Application.ensure_all_started(:plausible)
    execute(Timex.now())
  end

  @doc"""
    The email report should be sent on Monday at 9am according to the timezone
    of the site. This job runs every hour to be able to send it with hourly precision.
  """
  def execute(job_start) do
    send_weekly_emails(job_start)
    send_monthly_emails(job_start)
  end

  defp send_weekly_emails(job_start) do
    sites = Repo.all(
      from s in Plausible.Site,
      join: wr in Plausible.Site.WeeklyReport, on: wr.site_id == s.id,
      left_join: se in "sent_weekly_reports", on: se.site_id == s.id and se.year == fragment("EXTRACT(isoyear from (? at time zone ?))", ^job_start, s.timezone) and se.week == fragment("EXTRACT(week from (? at time zone ?))", ^job_start, s.timezone),
      where: is_nil(se), # We haven't sent a report for this site on this week
      where: fragment("EXTRACT(dow from (? at time zone ?))", ^job_start, s.timezone) == 1, # It's monday in the local timezone
      where: fragment("EXTRACT(hour from (? at time zone ?))", ^job_start, s.timezone) >= 9, # It's after 9am
      preload: [weekly_report: wr]
    )

    for site <- sites do
      query = Stats.Query.from(site.timezone, %{"period" => "7d"})

      for email <- site.weekly_report.recipients do
        Logger.info("Sending weekly report for #{URI.encode_www_form(site.domain)} to #{email}")
        unsubscribe_link = PlausibleWeb.Endpoint.url() <> "/sites/#{URI.encode_www_form(site.domain)}/weekly-report/unsubscribe?email=#{email}"
        send_report(email, site, "Weekly", unsubscribe_link, query)
      end

      weekly_report_sent(site, job_start)
    end
  end

  defp send_monthly_emails(job_start) do
    sites = Repo.all(
      from s in Plausible.Site,
      join: mr in Plausible.Site.MonthlyReport, on: mr.site_id == s.id,
      left_join: se in "sent_monthly_reports", on: se.site_id == s.id and se.year == fragment("EXTRACT(year from (? at time zone ?))", ^job_start, s.timezone) and se.month == fragment("EXTRACT(month from (? at time zone ?))", ^job_start, s.timezone),
      where: is_nil(se), # We haven't sent a report for this site this month
      where: fragment("EXTRACT(day from (? at time zone ?))", ^job_start, s.timezone) == 1, # It's the 1st of the month in the local timezone
      where: fragment("EXTRACT(hour from (? at time zone ?))", ^job_start, s.timezone) >= 9, # It's after 9am
      preload: [monthly_report: mr]
    )

    for site <- sites do
      last_month = job_start |> Timex.Timezone.convert(site.timezone) |> Timex.shift(months: -1) |> Timex.beginning_of_month
      query = Stats.Query.from(site.timezone, %{"period" => "month", "date" => Timex.format!(last_month, "{ISOdate}")})

      for email <- site.monthly_report.recipients do
        Logger.info("Sending monthly report for #{site.domain} to #{email}")
        unsubscribe_link = PlausibleWeb.Endpoint.url() <> "/sites/#{URI.encode_www_form(site.domain)}/monthly-report/unsubscribe?email=#{email}"
        send_report(email, site, Timex.format!(last_month, "{Mfull}"), unsubscribe_link, query)
      end

      monthly_report_sent(site, job_start)
    end
  end

  defp send_report(email, site, name, unsubscribe_link, query) do
    {pageviews, unique_visitors} = Stats.pageviews_and_visitors(site, query)
    {change_pageviews, change_visitors} = Stats.compare_pageviews_and_visitors(site, query, {pageviews, unique_visitors})
    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, Stats.Query.shift_back(query))
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate
    referrers = Stats.top_referrers(site, query)
    pages = Stats.top_pages(site, query)

    PlausibleWeb.Email.weekly_report(email, site,
      unique_visitors: unique_visitors,
      change_visitors: change_visitors,
      pageviews: pageviews,
      change_pageviews: change_pageviews,
      bounce_rate: bounce_rate,
      change_bounce_rate: change_bounce_rate,
      referrers: referrers,
      unsubscribe_link: unsubscribe_link,
      view_link: view_link(site, query),
      pages: pages,
      query: query,
      name: name
    ) |> Plausible.Mailer.deliver_now()
  end

  defp weekly_report_sent(site, time) do
    {year, week} = time |> DateTime.to_date |> Timex.iso_week

    Repo.insert_all("sent_weekly_reports", [%{
      site_id: site.id,
      year: year,
      week: week,
      timestamp: Timex.now()
    }])
  end

  defp monthly_report_sent(site, time) do
    date = DateTime.to_date(time)

    Repo.insert_all("sent_monthly_reports", [%{
      site_id: site.id,
      year: date.year,
      month: date.month,
      timestamp: Timex.now()
    }])
  end

  defp view_link(site, %Plausible.Stats.Query{period: "7d"}) do
    PlausibleWeb.Endpoint.url() <> "/#{URI.encode_www_form(site.domain)}?period=7d"
  end

  defp view_link(site, %Plausible.Stats.Query{period: "month", date_range: range}) do
    month = Timex.format!(range.first, "{ISOdate}")
    PlausibleWeb.Endpoint.url() <> "/#{URI.encode_www_form(site.domain)}?period=month&date=#{month}"
  end
end
