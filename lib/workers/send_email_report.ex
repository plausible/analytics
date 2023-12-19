defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1
  alias Plausible.Stats.{Query, Comparisons, Compare}
  alias Plausible.Stats

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "weekly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:weekly_report)

    if site do
      %{site: site}
      |> Map.put(:type, :weekly)
      |> Map.put(:name, "Weekly")
      |> put_last_week_query()
      |> put_stats_report()
      |> send_report_for_all(site.weekly_report.recipients)
    else
      :discard
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "monthly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:monthly_report)

    if site do
      %{site: site}
      |> Map.put(:type, :monthly)
      |> put_last_month_query()
      |> put_monthly_report_name()
      |> put_stats_report()
      |> send_report_for_all(site.monthly_report.recipients)
    else
      :discard
    end
  end

  defp send_report_for_all(_assigns, [] = _recipients), do: :ok

  defp send_report_for_all(assigns, [email | rest]) do
    unsubscribe_link =
      PlausibleWeb.Endpoint.url() <>
        "/sites/#{URI.encode_www_form(assigns.site.domain)}/#{assigns.type}-report/unsubscribe?email=#{email}"

    user = Plausible.Auth.find_user_by(email: email)
    login_link = user && Plausible.Sites.is_member?(user.id, assigns.site)

    template_assigns =
      assigns
      |> Map.put(:unsubscribe_link, unsubscribe_link)
      |> Map.put(:login_link, login_link)

    PlausibleWeb.Email.stats_report(email, template_assigns)
    |> Plausible.Mailer.send()

    send_report_for_all(assigns, rest)
  end

  defp put_last_month_query(%{site: site} = assigns) do
    last_month =
      Timex.now(site.timezone)
      |> Timex.shift(months: -1)
      |> Timex.beginning_of_month()
      |> Timex.format!("{ISOdate}")

    query = Query.from(site, %{"period" => "month", "date" => last_month})

    Map.put(assigns, :query, query)
  end

  defp put_last_week_query(%{site: site} = assigns) do
    today = Timex.now(site.timezone) |> DateTime.to_date()
    date = Timex.shift(today, weeks: -1) |> Timex.end_of_week() |> Date.to_iso8601()
    query = Query.from(site, %{"period" => "7d", "date" => date})

    Map.put(assigns, :query, query)
  end

  defp put_monthly_report_name(%{query: query} = assigns) do
    Map.put(assigns, :name, Timex.format!(query.date_range.first, "{Mfull}"))
  end

  defp put_stats_report(%{site: site, query: query} = assigns) do
    {:ok, prev_query} = Comparisons.compare(site, query, "previous_period")
    curr_period = Stats.aggregate(site, query, [:pageviews, :visitors, :bounce_rate])
    prev_period = Stats.aggregate(site, prev_query, [:pageviews, :visitors, :bounce_rate])

    source_query = Query.put_filter(query, "visit:source", {:is_not, "Direct / None"})

    assigns
    |> Map.merge(%{
      pageviews: curr_period[:pageviews][:value],
      change_pageviews: Compare.calculate_change(:pageviews, prev_period, curr_period),
      unique_visitors: curr_period[:visitors][:value],
      change_visitors: Compare.calculate_change(:visitors, prev_period, curr_period),
      bounce_rate: curr_period[:bounce_rate][:value],
      change_bounce_rate: Compare.calculate_change(:bounce_rate, prev_period, curr_period),
      pages: Stats.breakdown(site, query, "event:page", [:visitors], {5, 1}),
      sources: Stats.breakdown(site, source_query, "visit:source", [:visitors], {5, 1})
    })
  end
end
