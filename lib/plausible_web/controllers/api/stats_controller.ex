defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

  def main_graph(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

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
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_referrers = Stats.top_referrers(site, query, conn.params["limit"] || 5)
                            |> Enum.map(fn {name, count} -> %{name: name, count: count} end)
      json(conn, formatted_referrers)
    end
  end

  def referrer_drilldown(conn, %{"domain" => domain, "referrer" => referrer}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      referrers = Stats.referrer_drilldown(site, query, referrer)
                  |> Enum.map(fn {name, count} -> %{name: name, count: count} end)
      total_visitors = Stats.visitors_from_referrer(site, query, referrer)
      json(conn, %{referrers: referrers, total_visitors: total_visitors})
    end
  end

  def pages(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_pages = Stats.top_pages(site, query, conn.params["limit"] || 5)
                        |> Enum.map(fn {name, count} -> %{name: name, count: count} end)

      json(conn, formatted_pages)
    end
  end

  def countries(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_countries = Stats.countries(site, query, parse_integer(conn.params["limit"]) || 5)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_countries)
    end
  end

  def browsers(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_browsers = Stats.browsers(site, query, parse_integer(conn.params["limit"]) || 5)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_browsers)
    end
  end

  def operating_systems(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_systems = Stats.operating_systems(site, query, parse_integer(conn.params["limit"]) || 5)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_systems)
    end
  end

  def screen_sizes(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_sizes = Stats.top_screen_sizes(site, query)
                        |> Enum.map(fn {name, count, percentage} -> %{name: name, count: count, percentage: percentage} end)

      json(conn, formatted_sizes)
    end
  end

  def conversions(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    query = Stats.Query.from(site.timezone, conn.params)

    if site do
      formatted_conversions = Stats.goal_conversions(site, query)
                        |> Enum.map(fn {name, count} -> %{name: name, count: count} end)

      json(conn, formatted_conversions)
    end
  end

  def current_visitors(conn, %{"domain" => domain}) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site do
      json(conn, Stats.current_visitors(site))
    else
      render_error(conn, 404)
    end
  end

  defp parse_integer(nil), do: nil

  defp parse_integer(nr) do
    case Integer.parse(nr) do
      {number, ""} -> number
      _ -> nil
    end
  end
end
