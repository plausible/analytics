defmodule Plausible.Workers.SendEmailReport do
  use Plausible.Repo
  use Oban.Worker, queue: :send_email_reports, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"interval" => "weekly", "site_id" => site_id}}) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload(:weekly_report)

    if site && site.weekly_report do
      %{site: site}
      |> put_last_week_date()
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
      |> put_last_month_date()
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

  defp put_last_month_date(%{site: site} = assigns) do
    last_month =
      DateTime.now!(site.timezone)
      |> DateTime.shift(month: -1)
      |> DateTime.to_date()
      |> Date.beginning_of_month()
      |> Date.to_iso8601()

    Map.put(assigns, :date_param, last_month)
  end

  defp put_last_week_date(%{site: site} = assigns) do
    # In production, evaluating and sending the date param
    # is redundant since the default value is today for `site.timezone` and
    # weekly reports are always sent on Monday morning. However, this makes
    # it easier to test - no need for a `now` argument.
    date_param =
      site.timezone
      |> DateTime.now!()
      |> DateTime.to_date()
      |> Date.beginning_of_week()
      |> Date.to_iso8601()

    Map.put(assigns, :date_param, date_param)
  end

  defp put_date_range(%{date_param: date_param} = assigns) do
    date = Date.from_iso8601!(date_param)
    date_range = Date.range(date, date)
    Map.put(assigns, :date_range, date_range)
  end

  defp put_stats(%{site: site, date_param: date_param, type: :weekly} = assigns) do
    stats = Plausible.Stats.EmailReport.get_for_period(site, "7d", date_param)
    Map.put(assigns, :stats, stats)
  end

  defp put_stats(%{site: site, date_param: date_param, type: :monthly} = assigns) do
    stats = Plausible.Stats.EmailReport.get_for_period(site, "month", date_param)
    Map.put(assigns, :stats, stats)
  end

  defp put(assigns, key, value_fn) do
    Map.put(assigns, key, value_fn.(assigns))
  end
end
