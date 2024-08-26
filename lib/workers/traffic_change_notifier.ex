defmodule Plausible.Workers.TrafficChangeNotifier do
  @moduledoc """
  Oban service sending out traffic drop/spike notifications
  """
  use Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Site.TrafficChangeNotification

  alias PlausibleWeb.Router.Helpers, as: Routes

  use Oban.Worker, queue: :spike_notifications
  @at_most_every "12 hours"

  @impl Oban.Worker
  def perform(_job, clickhouse \\ Plausible.Stats.Clickhouse) do
    today = Date.utc_today()

    notifications =
      Repo.all(
        from sn in TrafficChangeNotification,
          where: is_nil(sn.last_sent),
          or_where: sn.last_sent < fragment("now() - INTERVAL ?", @at_most_every),
          join: s in Plausible.Site,
          on: sn.site_id == s.id,
          where: not s.locked,
          join: sm in Plausible.Site.Membership,
          on: sm.site_id == s.id,
          where: sm.role == :owner,
          join: u in Plausible.Auth.User,
          on: u.id == sm.user_id,
          where: is_nil(u.accept_traffic_until) or u.accept_traffic_until > ^today,
          preload: [site: s]
      )

    for notification <- notifications do
      case notification.type do
        :spike ->
          current_visitors = clickhouse.current_visitors(notification.site)

          if current_visitors >= notification.threshold do
            query = Query.from(notification.site, %{"period" => "realtime"})
            sources = clickhouse.top_sources_for_spike(notification.site, query, 3, 1)

            notify_spike(notification, current_visitors, sources)
          end

        :drop ->
          current_visitors = clickhouse.current_visitors_12h(notification.site)

          if current_visitors < notification.threshold do
            notify_drop(notification, current_visitors)
          end
      end
    end

    :ok
  end

  defp notify_spike(notification, current_visitors, sources) do
    for recipient <- notification.recipients do
      send_spike_notification(recipient, notification.site, current_visitors, sources)
    end

    notification
    |> TrafficChangeNotification.was_sent()
    |> Repo.update()
  end

  defp notify_drop(notification, current_visitors) do
    for recipient <- notification.recipients do
      send_drop_notification(recipient, notification.site, current_visitors)
    end

    notification
    |> TrafficChangeNotification.was_sent()
    |> Repo.update()
  end

  defp send_spike_notification(recipient, site, current_visitors, sources) do
    site = Repo.preload(site, :members)

    dashboard_link =
      if Enum.any?(site.members, &(&1.email == recipient)) do
        Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, [])
      end

    template =
      PlausibleWeb.Email.spike_notification(
        recipient,
        site,
        current_visitors,
        sources,
        dashboard_link
      )

    Plausible.Mailer.send(template)
  end

  defp send_drop_notification(recipient, site, current_visitors) do
    site = Repo.preload(site, :members)

    {dashboard_link, installation_link} =
      if Enum.any?(site.members, &(&1.email == recipient)) do
        {
          Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []),
          Routes.site_url(PlausibleWeb.Endpoint, :installation, site.domain, flow: "review")
        }
      else
        {nil, nil}
      end

    template =
      PlausibleWeb.Email.drop_notification(
        recipient,
        site,
        current_visitors,
        dashboard_link,
        installation_link
      )

    Plausible.Mailer.send(template)
  end
end
