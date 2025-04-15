defmodule Plausible.Workers.TrafficChangeNotifier do
  @moduledoc """
  Oban service sending out traffic drop/spike notifications
  """
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
          where: not s.locked,
          where: is_nil(t.accept_traffic_until) or t.accept_traffic_until > ^today,
          preload: [site: {s, team: t}]
      )

    for notification <- notifications do
      case notification.type do
        :spike ->
          current_visitors = Clickhouse.current_visitors(notification.site)

          if current_visitors >= notification.threshold do
            stats =
              notification.site
              |> get_traffic_spike_stats()
              |> Map.put(:current_visitors, current_visitors)

            notify_spike(notification, stats, now)
          end

        :drop ->
          current_visitors = Clickhouse.current_visitors_12h(notification.site)

          if current_visitors < notification.threshold do
            notify_drop(notification, current_visitors, now)
          end
      end
    end

    :ok
  end

  defp notify_spike(notification, stats, now) do
    for recipient <- notification.recipients do
      send_spike_notification(recipient, notification.site, stats)
    end

    notification
    |> TrafficChangeNotification.was_sent(now)
    |> Repo.update()
  end

  defp notify_drop(notification, current_visitors, now) do
    for recipient <- notification.recipients do
      send_drop_notification(recipient, notification.site, current_visitors)
    end

    notification
    |> TrafficChangeNotification.was_sent(now)
    |> Repo.update()
  end

  defp send_spike_notification(recipient, site, stats) do
    dashboard_link =
      if Repo.exists?(email_match_query(site, recipient)) do
        Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []) <>
          "?__team=#{site.team.identifier}"
      end

    template =
      PlausibleWeb.Email.spike_notification(
        recipient,
        site,
        stats,
        dashboard_link
      )

    Plausible.Mailer.send(template)
  end

  defp send_drop_notification(recipient, site, current_visitors) do
    {dashboard_link, installation_link} =
      if Repo.exists?(email_match_query(site, recipient)) do
        {
          Routes.stats_url(PlausibleWeb.Endpoint, :stats, site.domain, []) <>
            "?__team=#{site.team.identifier}",
          Routes.site_url(PlausibleWeb.Endpoint, :installation, site.domain,
            flow: PlausibleWeb.Flows.review()
          ) <> "&__team=#{site.team.identifier}"
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

  defp get_traffic_spike_stats(site) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          "site_id" => "#{site.id}",
          "metrics" => ["visitors"],
          "pagination" => %{"limit" => 3},
          "date_range" => "realtime"
        },
        %{}
      )

    %{}
    |> put_sources(site, query)
    |> put_pages(site, query)
  end

  defp put_sources(stats, site, query) do
    query =
      query
      |> Query.set(dimensions: ["visit:source"])
      |> Query.add_filter([:is_not, "visit:source", ["Direct / None"]])

    %{results: sources} = Plausible.Stats.query(site, query)

    Map.put(stats, :sources, sources)
  end

  defp put_pages(stats, site, query) do
    query = Query.set(query, dimensions: ["event:page"])

    %{results: pages} = Plausible.Stats.query(site, query)

    Map.put(stats, :pages, pages)
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
