defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

  def main_graph(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    plot_task = Task.async(fn -> Stats.calculate_plot(site, query) end)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {plot, labels, present_index} = Task.await(plot_task)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      pageviews: pageviews,
      unique_visitors: visitors,
      interval: query.step_type
    })
  end

  def referrers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_referrers = Stats.top_referrers(site, query)
                            |> Enum.map(fn {name, count} -> %{name: name, count: count} end)
      json(conn, formatted_referrers)
    end
  end

  def pages(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_pages = Stats.top_pages(site, query)
                        |> Enum.map(fn {name, count} -> %{name: name, count: count} end)

      json(conn, formatted_pages)
    end
  end

  def countries(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_countries = Stats.countries(site, query)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_countries)
    end
  end

  def browsers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_browsers = Stats.browsers(site, query)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_browsers)
    end
  end

  def operating_systems(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_systems = Stats.operating_systems(site, query)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_systems)
    end
  end

  def screen_sizes(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_sizes = Stats.top_screen_sizes(site, query)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_sizes)
    end
  end

  def conversions(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {conn, params} = fetch_period(conn, site)
    query = Stats.Query.from(site.timezone, params)

    if site do
      formatted_conversions = Stats.goal_conversions(site, query)
                        |> Enum.map(fn {name, count} -> %{name: name, count: count} end)

      json(conn, formatted_conversions)
    end
  end

  defp fetch_period(conn, site) do
    case conn.params["period"] do
      p when p in ["day", "month", "7d", "3mo", "6mo"] ->
        saved_periods = get_session(conn, :saved_periods) || %{}
        {put_session(conn, :saved_periods, Map.merge(saved_periods, %{site.domain => p})), conn.params}
      _ ->
        saved_period = (get_session(conn, :saved_periods) || %{})[site.domain]

        if saved_period do
          {conn, %{"period" => saved_period}}
        else
          {conn, conn.params}
        end
    end
  end
end
