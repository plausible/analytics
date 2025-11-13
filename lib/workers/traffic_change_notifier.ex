defmodule Plausible.Workers.TrafficChangeNotifier do
  @moduledoc """
  Oban service sending out traffic drop/spike notifications
  """
  use Plausible
  use Plausible.Repo
  alias Plausible.Stats.{Query, Clickhouse}
  alias Plausible.Site.TrafficChangeNotification

  alias PlausibleWeb.Router.Helpers, as: Routes

  use Oban.Worker, queue: :spike_notifications
  @min_interval_hours 12

  @impl Oban.Worker
  def perform(_job, now \\ NaiveDateTime.utc_now(:second)) do
    today = NaiveDateTime.to_date(now)

    notifications =
      Repo.all(
        from sn in TrafficChangeNotification,
          where:
            is_nil(sn.last_sent) or
              sn.last_sent < ^NaiveDateTime.add(now, -@min_interval_hours, :hour),
          inner_join: s in assoc(sn, :site),
          inner_join: t in assoc(s, :team),
          where: not t.locked,
          where: is_nil(t.accept_traffic_until) or t.accept_traffic_until > ^today,
          preload: [site: {s, team: t}]
      )

    for notification <- notifications, ok_to_send?(notification.site) do
      handle_notification(notification, now)
    end

    :ok
  end

  defp handle_notification(%TrafficChangeNotification{type: :spike} = notification, now) do
    current_visitors = Clickhouse.current_visitors(notification.site)

    if current_visitors >= notification.threshold do
      stats =
        notification.site
        |> get_traffic_spike_stats()
        |> Map.put(:current_visitors, current_visitors)

      notify_spike(notification, stats, now)
    end
  end

  defp handle_notification(%TrafficChangeNotification{type: :drop} = notification, now) do
    current_visitors = Clickhouse.current_visitors_12h(notification.site)

    if current_visitors < notification.threshold do
      notify_drop(notification, current_visitors, now)
    end
  end

  defp notify_spike(notification, stats, now) do
    for recipient_email <- notification.recipients do
      send_spike_notification(recipient_email, notification.site, stats)
    end

    notification
    |> TrafficChangeNotification.was_sent(now)
    |> Repo.update()
  end

  defp notify_drop(notification, current_visitors, now) do
    for recipient_email <- notification.recipients do
      send_drop_notification(recipient_email, notification.site, current_visitors)
    end

    notification
    |> TrafficChangeNotification.was_sent(now)
    |> Repo.update()
  end

  defp send_spike_notification(recipient_email, site, stats) do
    dashboard_link =
      if site_member?(site, recipient_email) do
        Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []) <>
          "?__team=#{site.team.identifier}"
      end

    template =
      PlausibleWeb.Email.spike_notification(
        recipient_email,
        site,
        stats,
        dashboard_link
      )

    Plausible.Mailer.send(template)
  end

  defp send_drop_notification(recipient_email, site, current_visitors) do
    site_member? = site_member?(site, recipient_email)

    dashboard_link =
      if site_member? do
        Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []) <>
          "?__team=#{site.team.identifier}"
      end

    installation_link =
      if site_member? and Plausible.Sites.regular?(site) do
        Routes.site_url(PlausibleWeb.Endpoint, :installation, site.domain,
          flow: PlausibleWeb.Flows.review()
        ) <> "&__team=#{site.team.identifier}"
      end

    template =
      PlausibleWeb.Email.drop_notification(
        recipient_email,
        site,
        current_visitors,
        dashboard_link,
        installation_link
      )

    Plausible.Mailer.send(template)
  end

  defp get_traffic_spike_stats(site) do
    %{}
    |> put_sources(site)
    |> put_pages(site)
  end

  @base_query_params %{
    "metrics" => ["visitors"],
    "pagination" => %{"limit" => 3},
    "date_range" => "realtime"
  }

  defp put_sources(stats, site) do
    query =
      Query.build!(
        site,
        :internal,
        Map.merge(@base_query_params, %{
          "site_id" => site.domain,
          "dimensions" => ["visit:source"],
          "filters" => [["is_not", "visit:source", ["Direct / None"]]]
        })
      )

    %{results: sources} = Plausible.Stats.query(site, query)

    Map.put(stats, :sources, sources)
  end

  defp put_pages(stats, site) do
    query =
      Query.build!(
        site,
        :internal,
        Map.merge(@base_query_params, %{
          "site_id" => site.domain,
          "dimensions" => ["event:page"]
        })
      )

    %{results: pages} = Plausible.Stats.query(site, query)

    Map.put(stats, :pages, pages)
  end

  defp site_member?(site, recipient_email) do
    from(tm in Plausible.Teams.Membership,
      inner_join: u in assoc(tm, :user),
      left_join: gm in assoc(tm, :guest_memberships),
      where: tm.team_id == ^site.team_id,
      where: tm.role != :guest or gm.site_id == ^site.id,
      where: u.email == ^recipient_email
    )
    |> Repo.exists?()
  end

  on_ee do
    defp ok_to_send?(site) do
      Plausible.Sites.regular?(site) or
        (Plausible.Sites.consolidated?(site) and
           Plausible.ConsolidatedView.ok_to_display?(site.team))
    end
  else
    defp ok_to_send?(_site), do: always(true)
  end
end
