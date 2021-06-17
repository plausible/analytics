defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats.Clickhouse, as: Stats
  alias Plausible.Stats.Query

  def main_graph(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    plot_task = Task.async(fn -> Stats.calculate_plot(site, query) end)
    {top_stats, sample_percent} = fetch_top_stats(site, query)
    {plot, labels, present_index} = Task.await(plot_task)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      top_stats: top_stats,
      interval: query.interval,
      sample_percent: sample_percent
    })
  end

  defp fetch_top_stats(site, %Query{period: "realtime"} = query) do
    stats = [
      %{
        name: "Current visitors",
        count: Stats.current_visitors(site, query)
      },
      %{
        name: "Unique visitors (last 30 min)",
        count: Stats.unique_visitors(site, query)
      },
      %{
        name: "Pageviews (last 30 min)",
        count: Stats.total_pageviews(site, query)
      }
    ]

    {stats, 100}
  end

  defp fetch_top_stats(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    total_filter = Map.merge(query.filters, %{"goal" => nil, "props" => nil})
    prev_query = Query.shift_back(query, site)
    unique_visitors = Stats.unique_visitors(site, %{query | filters: total_filter})
    prev_unique_visitors = Stats.unique_visitors(site, %{prev_query | filters: total_filter})
    {converted_visitors, sample_percent} = Stats.unique_visitors_with_sample_percent(site, query)
    prev_converted_visitors = Stats.unique_visitors(site, prev_query)
    completions = Stats.total_events(site, query)
    prev_completions = Stats.total_events(site, prev_query)

    conversion_rate = calculate_cr(unique_visitors, converted_visitors)
    prev_conversion_rate = calculate_cr(prev_unique_visitors, prev_converted_visitors)

    stats = [
      %{
        name: "Unique visitors",
        count: unique_visitors,
        change: percent_change(prev_unique_visitors, unique_visitors)
      },
      %{
        name: "Unique conversions",
        count: converted_visitors,
        change: percent_change(prev_converted_visitors, converted_visitors)
      },
      %{
        name: "Total conversions",
        count: completions,
        change: percent_change(prev_completions, completions)
      },
      %{
        name: "Conversion rate",
        percentage: conversion_rate,
        change: percent_change(prev_conversion_rate, conversion_rate)
      }
    ]

    {stats, sample_percent}
  end

  defp fetch_top_stats(site, query) do
    prev_query = Query.shift_back(query, site)

    {pageviews, visitors, sample_percent} =
      Stats.pageviews_and_visitors_with_sample_percent(site, query)

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
          duration: duration,
          change: percent_change(prev_duration, duration)
        }
      end

    time_on_page =
      if query.filters["page"] do
        [{success, duration}, {prev_success, prev_duration}] =
          Task.yield_many(
            [
              Task.async(fn ->
                {:ok, page_times} =
                  Stats.page_times_by_page_url(site, query, [query.filters["page"]])

                page_times
              end),
              Task.async(fn ->
                {:ok, page_times} =
                  Stats.page_times_by_page_url(site, prev_query, [query.filters["page"]])

                page_times
              end)
            ],
            5000
          )
          |> Enum.map(fn {task, response} ->
            case response do
              nil ->
                Task.shutdown(task, :brutal_kill)
                {nil, nil}

              {:ok, page_times} ->
                result = Enum.at(page_times.rows, 0)
                result = if result, do: Enum.at(result, 1), else: nil
                if result, do: {:ok, round(result)}, else: {:ok, 0}

              _ ->
                response
            end
          end)

        if success == :ok && prev_success == :ok do
          %{
            name: "Time on Page",
            duration: duration,
            change: percent_change(prev_duration, duration)
          }
        end
      end

    stats =
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
        visit_duration,
        time_on_page
      ]
      |> Enum.filter(& &1)

    {stats, sample_percent}
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

  def sources(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    include_details = params["detailed"] == "true"
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])
    show_noref = params["show_noref"] == "true"
    json(conn, Stats.top_sources(site, query, limit || 9, page || 1, show_noref, include_details))
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])
    show_noref = params["show_noref"] == "true"
    json(conn, Stats.utm_mediums(site, query, limit || 9, page || 1, show_noref))
  end

  def utm_campaigns(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])
    show_noref = params["show_noref"] == "true"
    json(conn, Stats.utm_campaigns(site, query, limit || 9, page || 1, show_noref))
  end

  def utm_sources(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])
    show_noref = params["show_noref"] == "true"
    json(conn, Stats.utm_sources(site, query, limit || 9, page || 1, show_noref))
  end

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)
    query = Query.from(site.timezone, params)

    search_terms =
      if site.google_auth && site.google_auth.property && !query.filters["goal"] do
        google_api().fetch_stats(site, query, params["limit"] || 9)
      end

    case search_terms do
      nil ->
        {_, total_visitors} = Stats.pageviews_and_visitors(site, query)
        user_id = get_session(conn, :current_user_id)
        is_admin = user_id && Plausible.Sites.has_admin_access?(user_id, site)
        json(conn, %{not_configured: true, is_admin: is_admin, total_visitors: total_visitors})

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
    include_details = params["detailed"] == "true"
    limit = params["limit"] || 9

    referrers = Stats.referrer_drilldown(site, query, referrer, include_details, limit)
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
    include_details = params["detailed"] == "true"
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])

    json(conn, Stats.top_pages(site, query, limit || 9, page || 1, include_details))
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])

    json(conn, Stats.entry_pages(site, query, limit || 9, page || 1))
  end

  def exit_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    limit = if params["limit"], do: String.to_integer(params["limit"])
    page = if params["page"], do: String.to_integer(params["page"])

    json(conn, Stats.exit_pages(site, query, limit || 9, page || 1))
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

  def browser_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.browser_versions(site, query, params["limit"] || 9))
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.operating_systems(site, query, params["limit"] || 9))
  end

  def operating_system_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.operating_system_versions(site, query, params["limit"] || 9))
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    json(conn, Stats.top_screen_sizes(site, query))
  end

  defp calculate_cr(unique_visitors, converted_visitors) do
    if unique_visitors > 0,
      do: Float.round(converted_visitors / unique_visitors * 100, 1),
      else: 0.0
  end

  def conversions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    total_filter = Map.merge(query.filters, %{"goal" => nil, "props" => nil})
    unique_visitors = Stats.unique_visitors(site, %{query | filters: total_filter})
    prop_names = Stats.all_props(site, query)

    conversions =
      Stats.goal_conversions(site, query)
      |> Enum.map(fn goal ->
        goal
        |> Map.put(:prop_names, prop_names[goal[:name]])
        |> Map.put(:conversion_rate, calculate_cr(unique_visitors, goal[:count]))
      end)

    json(conn, conversions)
  end

  def prop_breakdown(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)
    total_filter = Map.merge(query.filters, %{"goal" => nil, "props" => nil})
    unique_visitors = Stats.unique_visitors(site, %{query | filters: total_filter})

    props =
      Stats.property_breakdown(site, query, params["prop_name"])
      |> Enum.map(fn prop ->
        Map.put(prop, :conversion_rate, calculate_cr(unique_visitors, prop[:count]))
      end)

    json(conn, props)
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, %{"period" => "realtime"})
    json(conn, Stats.current_visitors(site, query))
  end

  defp google_api(), do: Application.fetch_env!(:plausible, :google_api)

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end
end
