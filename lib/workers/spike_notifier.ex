defmodule Plausible.Workers.SpikeNotifier do
  use Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Site.SpikeNotification
  use Oban.Worker, queue: :spike_notifications
  @at_most_every "12 hours"

  @impl Oban.Worker
  def perform(_args, _job, clickhouse \\ Plausible.Stats.Clickhouse) do
    notifications = Repo.all(
      from sn in SpikeNotification,
      where: is_nil(sn.last_sent),
      or_where: sn.last_sent < fragment("now() - INTERVAL ?", @at_most_every),
      preload: :site
    )

    for notification <- notifications do
      query = Query.from(notification.site.timezone, %{"period" => "realtime"})
      current_visitors = clickhouse.current_visitors(notification.site, query)
      sources = clickhouse.top_sources(notification.site, query, 3, 1, true)
      notify(notification, current_visitors, sources)
    end
  end

  def notify(notification, current_visitors, sources) do
    if current_visitors >= notification.threshold do
      for recipient <- notification.recipients do
        send_notification(recipient, notification.site, current_visitors, sources)
      end
      notification
      |> SpikeNotification.was_sent()
      |> Repo.update
    end
  end

  defp send_notification(recipient, site, current_visitors, sources) do
    site = Repo.preload(site, :members)

    dashboard_link = if Enum.member?(site.members, recipient) do
      PlausibleWeb.Endpoint.url() <> "/" <> URI.encode_www_form(site.domain)
    end

    template = PlausibleWeb.Email.spike_notification(recipient, site, current_visitors, sources, dashboard_link)
    try do
      Plausible.Mailer.send_email(template)
    rescue
      _ -> nil
    end
  end
end
