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
          where:
            is_nil(sn.last_sent) or sn.last_sent < fragment("now() - INTERVAL ?", @at_most_every),
          inner_join: s in assoc(sn, :site),
          inner_join: t in assoc(s, :team),
          where: not s.locked,
          where: is_nil(t.accept_traffic_until) or t.accept_traffic_until > ^today,
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
    dashboard_link =
      if Repo.exists?(email_match_query(site, recipient)) do
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
    {dashboard_link, installation_link} =
      if Repo.exists?(email_match_query(site, recipient)) do
        {
          Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []),
          Routes.site_url(PlausibleWeb.Endpoint, :installation, site.domain,
            flow: PlausibleWeb.Flows.review()
          )
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

  defp email_match_query(site, recipient) do
    from tm in Plausible.Teams.Membership,
      inner_join: u in assoc(tm, :user),
      left_join: gm in assoc(tm, :guest_memberships),
      where: tm.team_id == ^site.team_id,
      where: tm.role != :guest or gm.site_id == ^site.id,
      where: u.email == ^recipient
  end
end
