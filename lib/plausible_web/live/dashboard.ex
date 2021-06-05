defmodule PlausibleWeb.DashboardLive do
  use PlausibleWeb, :live_view
  use Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Stats.Clickhouse, as: Stats

  def mount(%{"domain" => site_domain}, session, socket) do
    socket =
      if connected?(socket) do
        site = Repo.get_by(Plausible.Site, domain: site_domain)

        user =
          Repo.get_by(Plausible.Auth.User, id: session["current_user_id"])
          |> Repo.preload(:subscription)

        assign(socket,
          site: site,
          site_domain: site.domain,
          current_user: user,
          top_stats: nil,
          pages: nil,
          sources: nil
        )
      else
        assign(socket,
          site_domain: site_domain,
          top_stats: nil,
          pages: nil,
          sources: nil
        )
      end

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    period = Map.get(params, "period", "12mo")

    send(self(), :fetch_graph)
    send(self(), :fetch_top_stats)
    send(self(), :fetch_pages)
    send(self(), :fetch_sources)

    {:noreply,
     assign(socket,
       period: period,
       graph: nil,
       top_stats: nil,
       pages: nil,
       sources: nil
     )}
  end

  def handle_info(:fetch_graph, socket) do
    site = socket.assigns[:site]
    query = Query.from(site.timezone, %{"period" => socket.assigns[:period]})

    prev_query = Query.shift_back(query, site)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {prev_pageviews, prev_visitors} = Stats.pageviews_and_visitors(site, prev_query)
    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, prev_query)
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate

    visit_duration =
      if !query.filters["page"] do
        duration = Stats.visit_duration(site, query)
        prev_duration = Stats.visit_duration(site, prev_query)

        %{
          name: "Visit duration",
          count: duration,
          change: percent_change(prev_duration, duration)
        }
      end

    top_stats =
      [
        %{
          name: "Unique visitors",
          count: visitors,
          change: percent_change(prev_visitors, visitors)
        },
        %{
          name: "Total pageviews",
          count: pageviews,
          change: percent_change(prev_pageviews, pageviews)
        },
        %{name: "Bounce rate", count: bounce_rate, change: change_bounce_rate},
        visit_duration
      ]
      |> Enum.filter(& &1)

    {plot, labels, present_index} = Stats.calculate_plot(socket.assigns[:site], query)

    socket = assign(socket, top_stats: top_stats)

    {:noreply,
     push_event(socket, "visitor_graph:loaded", %{
       plot: plot,
       labels: labels,
       present_index: present_index
     })}
  end

  def handle_info(:fetch_top_stats, socket) do
    site = socket.assigns[:site]
    query = Query.from(site.timezone, %{"period" => socket.assigns[:period]})

    prev_query = Query.shift_back(query, site)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {prev_pageviews, prev_visitors} = Stats.pageviews_and_visitors(site, prev_query)
    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, prev_query)
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate

    visit_duration =
      if !query.filters["page"] do
        duration = Stats.visit_duration(site, query)
        prev_duration = Stats.visit_duration(site, prev_query)

        %{
          name: "Visit duration",
          count: duration,
          change: percent_change(prev_duration, duration)
        }
      end

    top_stats =
      [
        %{
          name: "Unique visitors",
          count: visitors,
          change: percent_change(prev_visitors, visitors)
        },
        %{
          name: "Total pageviews",
          count: pageviews,
          change: percent_change(prev_pageviews, pageviews)
        },
        %{name: "Bounce rate", count: bounce_rate, change: change_bounce_rate},
        visit_duration
      ]
      |> Enum.filter(& &1)

    {:noreply, assign(socket, top_stats: top_stats)}
  end

  def handle_info(:fetch_pages, socket) do
    query = Query.from(socket.assigns[:site].timezone, %{"period" => socket.assigns[:period]})
    pages = Stats.top_pages(socket.assigns[:site], query, 9, 1, [])

    {:noreply, assign(socket, pages: pages)}
  end

  def handle_info(:fetch_sources, socket) do
    query = Query.from(socket.assigns[:site].timezone, %{"period" => socket.assigns[:period]})
    sources = Stats.top_sources(socket.assigns[:site], query, 9, 1, [])

    {:noreply, assign(socket, sources: sources)}
  end

  defp percent_change(old_count, new_count) do
    cond do
      old_count == 0 and new_count > 0 ->
        100

      old_count == 0 and new_count == 0 ->
        0

      true ->
        round((new_count - old_count) / old_count * 100)
    end
  end
end
