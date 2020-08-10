defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats.Clickhouse, as: Stats
  alias Plausible.Stats.Query
  plug PlausibleWeb.AuthorizeStatsPlug

  def main_graph(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    plot_task = Task.async(fn -> Stats.calculate_plot(site, query) end)
    top_stats = fetch_top_stats(site, query)
    {plot, labels, present_index} = Task.await(plot_task)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      top_stats: top_stats,
      interval: query.step_type
    })
  end

  defp fetch_top_stats(site, %Query{period: "realtime"} = query) do
    [
      %{
        name: "Active visitors",
        count: Stats.current_visitors(site, query)
      },
      %{
        name: "Pageviews (last 30 min)",
        count: Stats.total_pageviews(site, query)
      }
    ]
  end

  defp fetch_top_stats(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    prev_query = Query.shift_back(query)
    total_visitors = Stats.unique_visitors(site, %{query | filters: %{}})
    prev_total_visitors = Stats.unique_visitors(site, %{prev_query | filters: %{}})
    converted_visitors = Stats.unique_visitors(site, query)
    prev_converted_visitors = Stats.unique_visitors(site, prev_query)

    conversion_rate =
      if total_visitors > 0,
        do: Float.round(converted_visitors / total_visitors * 100, 1),
        else: 0.0

    prev_conversion_rate =
      if prev_total_visitors > 0,
        do: Float.round(prev_converted_visitors / prev_total_visitors * 100, 1),
        else: 0.0

    [
      %{
        name: "Total visitors",
        count: total_visitors,
        change: percent_change(prev_total_visitors, total_visitors)
      },
      %{
        name: "Converted visitors",
        count: converted_visitors,
        change: percent_change(prev_converted_visitors, converted_visitors)
      },
      %{
        name: "Conversion rate",
        percentage: conversion_rate,
        change: percent_change(prev_conversion_rate, conversion_rate)
      }
    ]
  end

  defp fetch_top_stats(site, query) do
    prev_query = Query.shift_back(query)
    {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)
    {prev_pageviews, prev_visitors} = Stats.pageviews_and_visitors(site, prev_query)
    bounce_rate = Stats.bounce_rate(site, query)
    prev_bounce_rate = Stats.bounce_rate(site, prev_query)
    change_bounce_rate = if prev_bounce_rate > 0, do: bounce_rate - prev_bounce_rate
    visit_duration = if !query.filters["page"] do
      duration = Stats.visit_duration(site, query)
      prev_duration = Stats.visit_duration(site, prev_query)

      %{
        name: "Visit duration",
        count: duration,
        change: percent_change(prev_duration, duration)
      }
    end

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
      %{name: "Bounce rate", percentage: bounce_rate, change: change_bounce_rate},
      visit_duration
    ] |> Enum.filter(&(&1))
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
    query = Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []
    limit = if params["limit"], do: String.to_integer(params["limit"])
    show_noref = params["show_noref"] == "true"
    json(conn, Stats.top_referrers(site, query, limit || 9, show_noref, include))
  end

  def referrers_for_goal(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.top_referrers_for_goal(site, query, params["limit"] || 9))
  end

  @google_api Application.fetch_env!(:plausible, :google_api)

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)
    query = Query.from(site.timezone, params)

    search_terms =
      if site.google_auth && site.google_auth.property && !query.filters["goal"] do
        @google_api.fetch_stats(site, query, params["limit"] || 9)
      end

    case search_terms do
      nil ->
        {_, total_visitors} = Stats.pageviews_and_visitors(site, query)
        user_id = get_session(conn, :current_user_id)
        is_owner = user_id && Plausible.Sites.is_owner?(user_id, site)
        json(conn, %{not_configured: true, is_owner: is_owner, total_visitors: total_visitors})

      {:ok, terms} ->
        {_, total_visitors} = Stats.pageviews_and_visitors(site, query)
        json(conn, %{search_terms: terms, total_visitors: total_visitors})

      {:error, e} ->
        put_status(conn, 500)
        |> json(%{error: e})
    end
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []
    limit = params["limit"] || 9

    referrers = Stats.referrer_drilldown(site, query, referrer, include, limit)
    {_, total_visitors} = Stats.pageviews_and_visitors(site, query)
    json(conn, %{referrers: referrers, total_visitors: total_visitors})
  end

  def referrer_drilldown_for_goal(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    referrers = Stats.referrer_drilldown_for_goal(site, query, referrer)
    total_visitors = Stats.conversions_from_referrer(site, query, referrer)
    json(conn, %{referrers: referrers, total_visitors: total_visitors})
  end

  def pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []
    limit = if params["limit"], do: String.to_integer(params["limit"])

    json(conn, Stats.top_pages(site, query, limit || 9, include))
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    include = if params["include"], do: String.split(params["include"], ","), else: []
    limit = if params["limit"], do: String.to_integer(params["limit"])

    json(conn, Stats.entry_pages(site, query, limit || 9, include))
  end

  def countries(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.countries(site, query))
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.browsers(site, query, params["limit"] || 9))
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.operating_systems(site, query, params["limit"] || 9))
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.top_screen_sizes(site, query))
  end

  def conversions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.goal_conversions(site, query))
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, %{"period" => "realtime"})
    json(conn, Stats.current_visitors(site, query))
  end
end
