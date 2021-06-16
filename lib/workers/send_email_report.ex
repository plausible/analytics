defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1
  alias Plausible.Stats.Query
  alias Plausible.Stats.Clickhouse, as: Stats

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "weekly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:weekly_report)
    today = Timex.now(site.timezone) |> DateTime.to_date()
    date = Timex.shift(today, weeks: -1) |> Timex.end_of_week() |> Date.to_iso8601()
    query = Query.from(site.timezone, %{"period" => "7d", "date" => date})

    for email <- site.weekly_report.recipients do
      unsubscribe_link =
        PlausibleWeb.Endpoint.url() <>
          "/sites/#{URI.encode_www_form(site.domain)}/weekly-report/unsubscribe?email=#{email}"

      send_report(email, site, "Weekly", unsubscribe_link, query)
    end

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "monthly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:monthly_report)

    last_month =
      Timex.now(site.timezone)
      |> Timex.shift(months: -1)
      |> Timex.beginning_of_month()

    query =
      Query.from(site.timezone, %{
        "period" => "month",
        "date" => Timex.format!(last_month, "{ISOdate}")
      })

    for email <- site.monthly_report.recipients do
      unsubscribe_link =
        PlausibleWeb.Endpoint.url() <>
          "/sites/#{URI.encode_www_form(site.domain)}/monthly-report/unsubscribe?email=#{email}"

      send_report(email, site, Timex.format!(last_month, "{Mfull}"), unsubscribe_link, query)
    end

    :ok
  end

  defp send_report(email, site, name, unsubscribe_link, query) do
    {pageviews, unique_visitors} = Stats.pageviews_and_visitors(site, query)

    {change_pageviews, change_visitors} =
      Stats.compare_pageviews_and_visitors(site, query, {pageviews, unique_visitors})

    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, Query.shift_back(query, site))
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate
    referrers = Stats.top_sources(site, query, 5, 1, [])
    pages = Stats.top_pages(site, query, 5, 1, [])
    user = Plausible.Auth.find_user_by(email: email)
    login_link = user && Plausible.Sites.is_member?(user.id, site)

    template =
      PlausibleWeb.Email.weekly_report(email, site,
        unique_visitors: unique_visitors,
        change_visitors: change_visitors,
        pageviews: pageviews,
        change_pageviews: change_pageviews,
        bounce_rate: bounce_rate,
        change_bounce_rate: change_bounce_rate,
        referrers: referrers,
        unsubscribe_link: unsubscribe_link,
        login_link: login_link,
        pages: pages,
        query: query,
        name: name
      )

    try do
      Plausible.Mailer.send_email(template)
    rescue
      _ -> nil
    end
  end
end
