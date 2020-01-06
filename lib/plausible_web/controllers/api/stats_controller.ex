defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats
  alias Plausible.Stats.Query
  plug :authorize

  def main_graph(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    plot_task = Task.async(fn -> Stats.calculate_plot(site, query) end)
    top_stats = fetch_top_stats(site, query)
    {plot, compare_plot, labels, present_index} = Task.await(plot_task)

    json(conn, %{
      plot: plot,
      compare_plot: compare_plot,
      labels: labels,
      present_index: present_index,
      top_stats: top_stats,
      interval: query.step_type,
    })
  end

  defp fetch_top_stats(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    prev_query = Query.shift_back(query)
    total_visitors = Stats.unique_visitors(site, %{query | filters: %{}})
    prev_total_visitors = Stats.unique_visitors(site, %{prev_query | filters: %{}})
    converted_visitors = Stats.unique_visitors(site, query)
    prev_converted_visitors = Stats.unique_visitors(site, prev_query)
    conversion_rate = if total_visitors > 0, do: Float.round(converted_visitors / total_visitors * 100, 1), else: 0.0
    prev_conversion_rate = if prev_total_visitors > 0, do: Float.round(prev_converted_visitors / prev_total_visitors * 100, 1), else: 0.0

    [
      %{name: "Total visitors", count: total_visitors, change: percent_change(prev_total_visitors, total_visitors)},
      %{name: "Converted visitors", count: converted_visitors, change: percent_change(prev_converted_visitors, converted_visitors)},
      %{name: "Conversion rate", percentage: conversion_rate, change: percent_change(prev_conversion_rate, conversion_rate)},
    ]
  end

  defp fetch_top_stats(site, query) do
    prev_query = Query.shift_back(query)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {prev_pageviews, prev_visitors} = Stats.pageviews_and_visitors(site, prev_query)
    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, prev_query)
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate

    [
      %{name: "Unique visitors", count: visitors, change: percent_change(prev_visitors, visitors)},
      %{name: "Total pageviews", count: pageviews, change: percent_change(prev_pageviews, pageviews)},
      %{name: "Bounce rate", percentage: bounce_rate, change: change_bounce_rate},
    ]
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

  def referrers(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []

    json(conn, Stats.top_referrers(site, query, params["limit"] || 5, include))
  end


  @google_api Application.fetch_env!(:plausible, :google_api)

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)
    query = Stats.Query.from(site.timezone, params)

    search_terms = if site.google_auth && site.google_auth.property && !query.filters["goal"] do
      @google_api.fetch_stats(site.google_auth, query)
    end

    case search_terms do
      nil ->
        total_visitors = Stats.visitors_from_referrer(site, query, "Google")
        user_id = get_session(conn, :current_user_id)
        is_owner = user_id && Plausible.Sites.is_owner?(user_id, site)
        json(conn, %{not_configured: true, is_owner: is_owner, total_visitors: total_visitors})
      {:ok, terms} ->
        total_visitors = Stats.visitors_from_referrer(site, query, "Google")
        json(conn, %{search_terms: terms, total_visitors: total_visitors})
      {:error, e} ->
        put_status(conn, 500)
        |> json(%{error: e})
    end
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []

    referrers = Stats.referrer_drilldown(site, query, referrer, include)
    total_visitors = Stats.visitors_from_referrer(site, query, referrer)
    json(conn, %{referrers: referrers, total_visitors: total_visitors})
  end

  def pages(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []

    json(conn, Stats.top_pages(site, query, params["limit"] || 5, include))
  end

  def countries(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    json(conn, Stats.countries(site, query, parse_integer(params["limit"]) || 5))
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    json(conn, Stats.browsers(site, query, parse_integer(params["limit"]) || 5))
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    json(conn, Stats.operating_systems(site, query, parse_integer(params["limit"]) || 5))
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    json(conn, Stats.top_screen_sizes(site, query))
  end

  def conversions(conn, params) do
    site = conn.assigns[:site]
    query = Stats.Query.from(site.timezone, params)

    json(conn, Stats.goal_conversions(site, query))
  end

  def current_visitors(conn, _) do
    json(conn, Stats.current_visitors(conn.assigns[:site]))
  end

  defp parse_integer(nil), do: nil

  defp parse_integer(nr) do
    case Integer.parse(nr) do
      {number, ""} -> number
      _ -> nil
    end
  end

  @doc """
    When the stats dashboard is loaded we make > 8 API calls. Instead of hitting the DB to authorize each
    request we 'memoize' the fact that the current user has access to the site stats. It is invalidated
    every 30 minutes and we hit the DB again to make sure their access hasn't been revoked.
  """
  def authorize(conn, _opts) do
    site_session_key = "authorized_site__" <> conn.params["domain"]
    user_id = get_session(conn, :current_user_id)

    case get_session(conn, site_session_key) do
      nil ->
        verify_access_via_db(conn, user_id, site_session_key)
      site_session ->
        if site_session[:valid_until] > DateTime.to_unix(Timex.now()) do
          assign(conn, :site, %Plausible.Site{
            id: site_session[:id],
            domain: site_session[:domain],
            timezone: site_session[:timezone]
          })
        else
          verify_access_via_db(conn, user_id, site_session_key)
        end
    end
  end

  defp verify_access_via_db(conn, user_id, site_session_key) do
    site = Repo.get_by(Plausible.Site, domain: conn.params["domain"])

    if !site do
      send_resp(conn, 401, "") |> halt
    else
      can_access = site.public || (user_id && Plausible.Sites.is_owner?(user_id, site))

      if !can_access do
        send_resp(conn, 401, "") |> halt
      else
        put_session(conn, site_session_key, %{
          id: site.id,
          domain: site.domain,
          timezone: site.timezone,
          valid_until: Timex.now() |> Timex.shift(minutes: 30) |> DateTime.to_unix()
        })
        |> assign(:site, site)
      end
    end
  end
end
