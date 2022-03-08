defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1
  alias Plausible.Stats.Query
  alias Plausible.Stats

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "weekly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:weekly_report)
    today = Timex.now(site.timezone) |> DateTime.to_date()
    date = Timex.shift(today, weeks: -1) |> Timex.end_of_week() |> Date.to_iso8601()
    query = Query.from(site, %{"period" => "7d", "date" => date})

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
      Query.from(site, %{
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
    prev_query = Query.shift_back(query, site)
    curr_period = Stats.aggregate(site, query, [:pageviews, :visitors, :bounce_rate])
    prev_period = Stats.aggregate(site, prev_query, [:pageviews, :visitors, :bounce_rate])

    change_pageviews = Stats.Compare.calculate_change(:pageviews, prev_period, curr_period)
    change_visitors = Stats.Compare.calculate_change(:visitors, prev_period, curr_period)
    change_bounce_rate = Stats.Compare.calculate_change(:bounce_rate, prev_period, curr_period)

    source_query = Query.put_filter(query, "visit:source", {:is_not, "Direct / None"})
    sources = Stats.breakdown(site, source_query, "visit:source", [:visitors], {5, 1})
    pages = Stats.breakdown(site, query, "event:page", [:visitors], {5, 1})
    user = Plausible.Auth.find_user_by(email: email)
    login_link = user && Plausible.Sites.is_member?(user.id, site)

    template =
      PlausibleWeb.Email.weekly_report(email, site,
        unique_visitors: curr_period[:visitors][:value],
        change_visitors: change_visitors,
        pageviews: curr_period[:pageviews][:value],
        change_pageviews: change_pageviews,
        bounce_rate: curr_period[:bounce_rate][:value],
        change_bounce_rate: change_bounce_rate,
        sources: sources,
        unsubscribe_link: unsubscribe_link,
        login_link: login_link,
        pages: pages,
        query: query,
        name: name
      )

    Plausible.Mailer.send_email_safe(template)
  end
end
