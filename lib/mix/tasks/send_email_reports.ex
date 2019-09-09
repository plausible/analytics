defmodule Mix.Tasks.SendEmailReports do
  use Mix.Task
  use Plausible.Repo
  require Logger

  def run(args) do
    Application.ensure_all_started(:plausible)
    execute(args)
  end

  @doc"""
    The email report should be sent on Monday at 9am according to the timezone
    of the site. This job runs every hour to be able to send it with hourly precision.
  """
  def execute(args \\ []) do
    sites = Repo.all(
      from s in Plausible.Site,
      join: wr in Plausible.Site.WeeklyReport, on: wr.site_id == s.id,
      left_join: se in "sent_weekly_reports", on: se.site_id == s.id and se.year == fragment("EXTRACT(year from (now() at time zone ?))", s.timezone) and se.week == fragment("EXTRACT(week from (now() at time zone ?))", s.timezone),
      where: is_nil(se), # We haven't sent a report for this site on this week
      where: fragment("EXTRACT(dow from (now() at time zone ?))", s.timezone) == 1, # It's monday in the local timezone
      where: fragment("EXTRACT(hour from (now() at time zone ?))", s.timezone) >= 9, # It's after 9am
      select: s,
      preload: [weekly_report: wr]
    )

    for site <- sites do
      email = site.weekly_report.email
      IO.puts("Sending email report for #{site.domain} to #{email}")
      send_report(email, site)
    end
  end

  defp send_report(email, site) do
    query = Plausible.Stats.Query.from(site.timezone, %{"period" => "7d"})
    {pageviews, unique_visitors} = Plausible.Stats.pageviews_and_visitors(site, query)
    {change_pageviews, change_visitors} = Plausible.Stats.compare_pageviews_and_visitors(site, query, {pageviews, unique_visitors})
    referrers = Plausible.Stats.top_referrers(site, query)
    pages = Plausible.Stats.top_pages(site, query)
    settings_link = PlausibleWeb.Endpoint.url() <> "/#{site.domain}/settings#email-reports"
    view_link = PlausibleWeb.Endpoint.url() <> "/#{site.domain}?period=7d"

    PlausibleWeb.Email.weekly_report(email, site,
      unique_visitors: unique_visitors,
      change_visitors: change_visitors,
      pageviews: pageviews,
      change_pageviews: change_pageviews,
      referrers: referrers,
      settings_link: settings_link,
      view_link: view_link,
      pages: pages,
      query: query
    ) |> Plausible.Mailer.deliver_now()

    email_report_sent(site)
  end

  defp email_report_sent(site) do
    {year, week} = Timex.now(site.timezone) |> DateTime.to_date |> Timex.iso_week

    Repo.insert_all("sent_weekly_reports", [%{
      site_id: site.id,
      year: year,
      week: week,
      timestamp: Timex.now()
    }])
  end
end
