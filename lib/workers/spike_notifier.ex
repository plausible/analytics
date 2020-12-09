defmodule Plausible.Workers.SpikeNotifier do
  use Plausible.Repo
  alias Plausible.Stats.Query
  use Oban.Worker, queue: :spike_notifications
  @at_most_every "12 hours"

  @impl Oban.Worker
  def perform(_args, _job, clickhouse \\ Plausible.Stats.Clickhouse) do
    notifications = Repo.all(
      from sn in Plausible.Site.SpikeNotification,
      where: is_nil(sn.last_sent),
      or_where: sn.last_sent < fragment("now() - INTERVAL ?", @at_most_every)
    )

    for notification <- notifications do
      notification = Repo.preload(notification, :site)
      query = Query.from(notification.site.timezone, %{"period" => "realtime"})
      current_visitors = clickhouse.current_visitors(notification.site, query)
      notify(notification, current_visitors)
    end
  end

  def notify(notification, current_visitors) do
    if current_visitors >= notification.threshold do
      for recipient <- notification.recipients do
        send_notification(recipient, notification.site, current_visitors)
      end
    end
  end

  defp send_notification(recipient, site, current_visitors) do
    template = PlausibleWeb.Email.spike_notification(recipient, site, current_visitors)
    try do
      Plausible.Mailer.send_email(template)
    rescue
      _ -> nil
    end
  end
end
