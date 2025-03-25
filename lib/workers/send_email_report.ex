defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1
  alias Plausible.Stats.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "weekly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:weekly_report)

    if site && site.weekly_report do
      %{site: site}
      |> put_last_week_query()
      |> put_date_range()
      |> Map.put(:type, :weekly)
      |> Map.put(:name, "Weekly")
      |> put(:date, &Calendar.strftime(&1.date_range.last, "%-d %b %Y"))
      |> put_stats()
      |> send_report_for_all(site.weekly_report.recipients)
    else
      :discard
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "monthly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:monthly_report)

    if site && site.monthly_report do
      %{site: site}
      |> put_last_month_query()
      |> put_date_range()
      |> Map.put(:type, :monthly)
      |> put(:name, &Calendar.strftime(&1.date_range.first, "%B"))
      |> put(:date, &Calendar.strftime(&1.date_range.last, "%-d %b %Y"))
      |> put_stats()
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
    login_link = user && Plausible.Teams.Memberships.site_member?(assigns.site, user)

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
      DateTime.now!(site.timezone)
      |> DateTime.shift(month: -1)
      |> Timex.beginning_of_month()
      |> Date.to_iso8601()

    query = Query.from(site, %{"period" => "month", "date" => last_month})

    Map.put(assigns, :query, query)
  end

  defp put_last_week_query(%{site: site} = assigns) do
    date = DateTime.now!(site.timezone) |> Timex.beginning_of_week() |> Date.to_iso8601()
    query = Query.from(site, %{"period" => "7d", "date" => date})

    Map.put(assigns, :query, query)
  end

  defp put_date_range(%{query: query} = assigns) do
    Map.put(assigns, :date_range, Query.date_range(query))
  end

  defp put_stats(%{site: site, query: query} = assigns) do
    Map.put(assigns, :stats, Plausible.Stats.EmailReport.get(site, query))
  end

  defp put(assigns, key, value_fn) do
    Map.put(assigns, key, value_fn.(assigns))
  end
end
