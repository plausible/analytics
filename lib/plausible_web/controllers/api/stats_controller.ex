defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats
  alias Plausible.Stats.{Query, Filters}

  def main_graph(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    timeseries_query =
      if query.period == "realtime" do
        %Query{query | period: "30m"}
      else
        query
      end

    timeseries = Task.async(fn -> Stats.timeseries(site, timeseries_query, [:visitors]) end)
    {top_stats, sample_percent} = fetch_top_stats(site, query)

    timeseries_result = Task.await(timeseries)
    plot = Enum.map(timeseries_result, fn row -> row[:visitors] end)
    labels = Enum.map(timeseries_result, fn row -> row[:date] end)
    present_index = present_index_for(site, query, labels)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      top_stats: top_stats,
      interval: query.interval,
      sample_percent: sample_percent,
      with_imported: query.include_imported,
      imported_source: site.imported_data && site.imported_data.source
    })
  end

  defp present_index_for(site, query, dates) do
    case query.interval do
      "hour" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:00:00")

        Enum.find_index(dates, &(&1 == current_date))

      "date" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()

        Enum.find_index(dates, &(&1 == current_date))

      "month" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> Timex.beginning_of_month()

        Enum.find_index(dates, &(&1 == current_date))

      "minute" ->
        nil
    end
  end

  defp fetch_top_stats(site, %Query{period: "realtime"} = query) do
    query_30m = %Query{query | period: "30m"}

    %{
      visitors: %{value: visitors},
      pageviews: %{value: pageviews}
    } = Stats.aggregate(site, query_30m, [:visitors, :pageviews])

    stats = [
      %{
        name: "Current visitors",
        value: Stats.current_visitors(site)
      },
      %{
        name: "Unique visitors (last 30 min)",
        value: visitors
      },
      %{
        name: "Pageviews (last 30 min)",
        value: pageviews
      }
    ]

    {stats, 100}
  end

  defp fetch_top_stats(site, %Query{filters: %{"event:goal" => _goal}} = query) do
    total_q = Query.remove_goal(query)
    prev_query = Query.shift_back(query, site)
    prev_total_query = Query.shift_back(total_q, site)

    %{
      visitors: %{value: unique_visitors}
    } = Stats.aggregate(site, total_q, [:visitors])

    %{
      visitors: %{value: prev_unique_visitors}
    } = Stats.aggregate(site, prev_total_query, [:visitors])

    %{
      visitors: %{value: converted_visitors},
      events: %{value: completions}
    } = Stats.aggregate(site, query, [:visitors, :events])

    %{
      visitors: %{value: prev_converted_visitors},
      events: %{value: prev_completions}
    } = Stats.aggregate(site, prev_query, [:visitors, :events])

    conversion_rate = calculate_cr(unique_visitors, converted_visitors)
    prev_conversion_rate = calculate_cr(prev_unique_visitors, prev_converted_visitors)

    stats = [
      %{
        name: "Unique visitors",
        value: unique_visitors,
        change: percent_change(prev_unique_visitors, unique_visitors)
      },
      %{
        name: "Unique conversions",
        value: converted_visitors,
        change: percent_change(prev_converted_visitors, converted_visitors)
      },
      %{
        name: "Total conversions",
        value: completions,
        change: percent_change(prev_completions, completions)
      },
      %{
        name: "Conversion rate",
        value: conversion_rate,
        change: percent_change(prev_conversion_rate, conversion_rate)
      }
    ]

    {stats, 100}
  end

  defp fetch_top_stats(site, query) do
    prev_query = Query.shift_back(query, site)

    metrics =
      if query.filters["event:page"] do
        [:visitors, :pageviews, :bounce_rate, :time_on_page, :sample_percent]
      else
        [:visitors, :pageviews, :bounce_rate, :visit_duration, :sample_percent]
      end

    current_results = Stats.aggregate(site, query, metrics)
    prev_results = Stats.aggregate(site, prev_query, metrics)

    stats =
      [
        top_stats_entry(current_results, prev_results, "Unique visitors", :visitors),
        top_stats_entry(current_results, prev_results, "Total pageviews", :pageviews),
        top_stats_entry(current_results, prev_results, "Bounce rate", :bounce_rate),
        top_stats_entry(current_results, prev_results, "Visit duration", :visit_duration),
        top_stats_entry(current_results, prev_results, "Time on page", :time_on_page)
      ]
      |> Enum.filter(& &1)

    {stats, current_results[:sample_percent][:value]}
  end

  defp top_stats_entry(current_results, prev_results, name, key) do
    if current_results[key] do
      %{
        name: name,
        value: current_results[key][:value],
        change: calculate_change(key, prev_results[key][:value], current_results[key][:value])
      }
    end
  end

  defp calculate_change(:bounce_rate, old_count, new_count) do
    if old_count > 0, do: new_count - old_count
  end

  defp calculate_change(_metric, old_count, new_count) do
    percent_change(old_count, new_count)
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

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:source", params)

    pagination = parse_pagination(params)

    metrics =
      if params["detailed"], do: [:visitors, :bounce_rate, :visit_duration], else: [:visitors]

    res =
      Stats.breakdown(site, query, "visit:source", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :source, "visit:source")
      |> transform_keys(%{source: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_medium", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_medium", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :utm_medium, "visit:utm_medium")
      |> transform_keys(%{utm_medium: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def utm_campaigns(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_campaign", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_campaign", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :utm_campaign, "visit:utm_campaign")
      |> transform_keys(%{utm_campaign: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def utm_contents(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_content", params)

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_content", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :utm_content, "visit:utm_content")
      |> transform_keys(%{utm_content: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def utm_terms(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_term", params)

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_term", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :utm_term, "visit:utm_term")
      |> transform_keys(%{utm_term: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def utm_sources(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_source", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_source", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :utm_source, "visit:utm_source")
      |> transform_keys(%{utm_source: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, res)
    end
  end

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)

    query =
      Query.from(site, params)
      |> Query.put_filter("source", "Google")
      |> Filters.add_prefix()

    search_terms =
      if site.google_auth && site.google_auth.property && !query.filters["goal"] do
        google_api().fetch_stats(site, query, params["limit"] || 9)
      end

    %{:visitors => %{value: total_visitors}} = Stats.aggregate(site, query, [:visitors])

    case search_terms do
      nil ->
        user_id = get_session(conn, :current_user_id)
        is_admin = user_id && Plausible.Sites.has_admin_access?(user_id, site)
        json(conn, %{not_configured: true, is_admin: is_admin, total_visitors: total_visitors})

      {:ok, terms} ->
        json(conn, %{search_terms: terms, total_visitors: total_visitors})

      {:error, e} ->
        put_status(conn, 500)
        |> json(%{error: e})
    end
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Query.put_filter("source", referrer)
      |> Filters.add_prefix()

    pagination = parse_pagination(params)

    metrics =
      if params["detailed"], do: [:visitors, :bounce_rate, :visit_duration], else: [:visitors]

    referrers =
      Stats.breakdown(site, query, "visit:referrer", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :referrer, "visit:referrer")
      |> transform_keys(%{referrer: :name})
      |> Enum.map(&Map.drop(&1, [:visits]))

    %{:visitors => %{value: total_visitors}} = Stats.aggregate(site, query, [:visitors])
    json(conn, %{referrers: referrers, total_visitors: total_visitors})
  end

  def pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    metrics =
      if params["detailed"],
        do: [:visitors, :pageviews, :bounce_rate, :time_on_page],
        else: [:visitors]

    pagination = parse_pagination(params)

    pages =
      Stats.breakdown(site, query, "event:page", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :page, "event:page")
      |> transform_keys(%{page: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        pages
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        pages |> to_csv([:name, :visitors, :bounce_rate, :time_on_page])
      end
    else
      json(conn, pages)
    end
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)
    metrics = [:visitors, :visits, :visit_duration]

    entry_pages =
      Stats.breakdown(site, query, "visit:entry_page", metrics, pagination)
      |> maybe_add_cr(site, query, pagination, :entry_page, "visit:entry_page")
      |> transform_keys(%{
        entry_page: :name,
        visitors: :unique_entrances,
        visits: :total_entrances
      })

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        entry_pages
        |> transform_keys(%{unique_entrances: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        entry_pages |> to_csv([:name, :unique_entrances, :total_entrances, :visit_duration])
      end
    else
      json(conn, entry_pages)
    end
  end

  def exit_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    {limit, page} = parse_pagination(params)
    metrics = [:visitors, :visits]

    exit_pages =
      Stats.breakdown(site, query, "visit:exit_page", metrics, {limit, page})
      |> maybe_add_cr(site, query, {limit, page}, :exit_page, "visit:exit_page")
      |> transform_keys(%{
        exit_page: :name,
        visitors: :unique_exits,
        visits: :total_exits
      })

    pages = Enum.map(exit_pages, & &1[:name])

    total_visits_query =
      Query.put_filter(query, "event:page", {:member, pages})
      |> Query.put_filter("event:goal", nil)
      |> Query.put_filter("event:name", {:is, "pageview"})
      |> Query.put_filter("visit:goal", query.filters["event:goal"])
      |> Query.put_filter("visit:page", query.filters["event:page"])

    total_pageviews =
      Stats.breakdown(site, total_visits_query, "event:page", [:pageviews], {limit, 1})

    exit_pages =
      Enum.map(exit_pages, fn exit_page ->
        exit_rate =
          case Enum.find(total_pageviews, &(&1[:page] == exit_page[:name])) do
            %{pageviews: pageviews} ->
              Float.floor(exit_page[:total_exits] / pageviews * 100)

            nil ->
              nil
          end

        Map.put(exit_page, :exit_rate, exit_rate)
      end)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        exit_pages
        |> transform_keys(%{unique_exits: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        exit_pages |> to_csv([:name, :unique_exits, :total_exits, :exit_rate])
      end
    else
      json(conn, exit_pages)
    end
  end

  def countries(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:country", {:is_not, "\0\0"})

    pagination = parse_pagination(params)

    countries =
      Stats.breakdown(site, query, "visit:country", [:visitors], pagination)
      |> maybe_add_cr(site, query, {300, 1}, :country, "visit:country")
      |> transform_keys(%{country: :code})
      |> maybe_add_percentages(query)

    if params["csv"] do
      countries =
        countries
        |> Enum.map(fn country ->
          country_info = get_country(country[:code])
          Map.put(country, :name, country_info.name)
        end)

      if Map.has_key?(query.filters, "event:goal") do
        countries
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        countries |> to_csv([:name, :visitors])
      end
    else
      countries =
        Enum.map(countries, fn row ->
          country = get_country(row[:code])

          if country do
            Map.merge(row, %{
              name: country.name,
              flag: country.flag,
              alpha_3: country.alpha_3,
              code: country.alpha_2
            })
          else
            Map.merge(row, %{
              name: row[:code],
              flag: "",
              alpha_3: "",
              code: ""
            })
          end
        end)

      json(conn, countries)
    end
  end

  def regions(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:region", {:is_not, ""})

    pagination = parse_pagination(params)

    regions =
      Stats.breakdown(site, query, "visit:region", [:visitors], pagination)
      |> transform_keys(%{region: :code})
      |> Enum.map(fn region ->
        region_entry = Location.get_subdivision(region[:code])

        if region_entry do
          country_entry = get_country(region_entry.country_code)
          Map.merge(region, %{name: region_entry.name, country_flag: country_entry.flag})
        else
          Sentry.capture_message("Could not find region info", extra: %{code: region[:code]})
          Map.merge(region, %{name: region[:code]})
        end
      end)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        regions
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        regions |> to_csv([:name, :visitors])
      end
    else
      json(conn, regions)
    end
  end

  def cities(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:city", {:is_not, 0})

    pagination = parse_pagination(params)

    cities =
      Stats.breakdown(site, query, "visit:city", [:visitors], pagination)
      |> transform_keys(%{city: :code})
      |> Enum.map(fn city ->
        city_info = Location.get_city(city[:code])

        if city_info do
          country_info = get_country(city_info.country_code)

          Map.merge(city, %{
            name: city_info.name,
            country_flag: country_info.flag
          })
        else
          Sentry.capture_message("Could not find city info", extra: %{code: city[:code]})

          Map.merge(city, %{name: "N/A"})
        end
      end)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        cities
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        cities |> to_csv([:name, :visitors])
      end
    else
      json(conn, cities)
    end
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    browsers =
      Stats.breakdown(site, query, "visit:browser", [:visitors], pagination)
      |> maybe_add_cr(site, query, pagination, :browser, "visit:browser")
      |> transform_keys(%{browser: :name})
      |> maybe_add_percentages(query)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        browsers
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        browsers |> to_csv([:name, :visitors])
      end
    else
      json(conn, browsers)
    end
  end

  def browser_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    versions =
      Stats.breakdown(site, query, "visit:browser_version", [:visitors], pagination)
      |> maybe_add_cr(site, query, pagination, :browser_version, "visit:browser_version")
      |> transform_keys(%{browser_version: :name})
      |> maybe_add_percentages(query)

    json(conn, versions)
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    systems =
      Stats.breakdown(site, query, "visit:os", [:visitors], pagination)
      |> maybe_add_cr(site, query, pagination, :os, "visit:os")
      |> transform_keys(%{os: :name})
      |> maybe_add_percentages(query)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        systems
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        systems |> to_csv([:name, :visitors])
      end
    else
      json(conn, systems)
    end
  end

  def operating_system_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    versions =
      Stats.breakdown(site, query, "visit:os_version", [:visitors], pagination)
      |> maybe_add_cr(site, query, pagination, :os_version, "visit:os_version")
      |> transform_keys(%{os_version: :name})
      |> maybe_add_percentages(query)

    json(conn, versions)
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    sizes =
      Stats.breakdown(site, query, "visit:device", [:visitors], pagination)
      |> maybe_add_cr(site, query, pagination, :device, "visit:device")
      |> transform_keys(%{device: :name})
      |> maybe_add_percentages(query)

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        sizes
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        sizes |> to_csv([:name, :visitors])
      end
    else
      json(conn, sizes)
    end
  end

  defp calculate_cr(nil, _converted_visitors), do: 100.0

  defp calculate_cr(unique_visitors, converted_visitors) do
    if unique_visitors > 0,
      do: Float.round(converted_visitors / unique_visitors * 100, 1),
      else: 0.0
  end

  def conversions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    query =
      if query.period == "realtime" do
        %Query{query | period: "30m"}
      else
        query
      end

    total_q = Query.remove_goal(query)

    %{visitors: %{value: total_visitors}} = Stats.aggregate(site, total_q, [:visitors])

    prop_names =
      if query.filters["event:goal"] do
        Stats.props(site, query)
      else
        %{}
      end

    conversions =
      Stats.breakdown(site, query, "event:goal", [:visitors, :events], {100, 1})
      |> transform_keys(%{
        goal: :name,
        visitors: :unique_conversions,
        events: :total_conversions
      })
      |> Enum.map(fn goal ->
        goal
        |> Map.put(:prop_names, prop_names[goal[:name]])
        |> Map.put(:conversion_rate, calculate_cr(total_visitors, goal[:unique_conversions]))
      end)

    if params["csv"] do
      conversions |> to_csv([:name, :unique_conversions, :total_conversions])
    else
      json(conn, conversions)
    end
  end

  def prop_breakdown(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    total_q = Query.remove_goal(query)

    %{:visitors => %{value: unique_visitors}} = Stats.aggregate(site, total_q, [:visitors])

    prop_name = "event:props:" <> params["prop_name"]

    props =
      Stats.breakdown(site, query, prop_name, [:visitors, :events], pagination)
      |> transform_keys(%{
        params["prop_name"] => :name,
        :events => :total_conversions,
        :visitors => :unique_conversions
      })
      |> Enum.map(fn prop ->
        Map.put(
          prop,
          :conversion_rate,
          calculate_cr(unique_visitors, prop[:unique_conversions])
        )
      end)

    if params["csv"] do
      props
    else
      json(conn, props)
    end
  end

  def all_props_breakdown(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    prop_names =
      if query.filters["event:goal"] do
        {_, _, goal} = query.filters["event:goal"]

        Stats.props(site, query)
        |> Map.get(goal, [])
      else
        []
      end

    values =
      prop_names
      |> Enum.map(fn prop ->
        prop_breakdown(conn, Map.put(params, "prop_name", prop))
        |> Enum.map(&Map.put(&1, :prop, prop))
      end)
      |> Enum.concat()

    to_csv(values, [:prop, :name, :unique_conversions, :total_conversions])
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    json(conn, Stats.current_visitors(site))
  end

  defp google_api(), do: Application.fetch_env!(:plausible, :google_api)

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end

  def filter_suggestions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    json(conn, Stats.filter_suggestions(site, query, params["filter_name"], params["q"]))
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end

  defp parse_pagination(params) do
    limit = if params["limit"], do: String.to_integer(params["limit"]), else: 9
    page = if params["page"], do: String.to_integer(params["page"]), else: 1
    {limit, page}
  end

  defp maybe_add_percentages(stat_list, query) do
    if Map.has_key?(query.filters, "event:goal") do
      stat_list
    else
      total = Enum.reduce(stat_list, 0, fn %{visitors: count}, total -> total + count end)

      Enum.map(stat_list, fn stat ->
        Map.put(stat, :percentage, round(stat[:visitors] / total * 100))
      end)
    end
  end

  defp maybe_hide_noref(query, property, params) do
    cond do
      is_nil(query.filters[property]) and params["show_noref"] != "true" ->
        new_filters = Map.put(query.filters, property, {:is_not, "Direct / None"})
        %Query{query | filters: new_filters}

      true ->
        query
    end
  end

  defp add_cr(list, list_without_goals, key_name) do
    Enum.map(list, fn item ->
      without_goal = Enum.find(list_without_goals, fn s -> s[key_name] === item[key_name] end)

      item
      |> Map.put(:total_visitors, without_goal[:visitors])
      |> Map.put(:conversion_rate, calculate_cr(without_goal[:visitors], item[:visitors]))
    end)
  end

  defp maybe_add_cr([], _site, _query, _pagination, _key_name, _filter_name), do: []

  defp maybe_add_cr(list, site, query, pagination, key_name, filter_name) do
    if Map.has_key?(query.filters, "event:goal") do
      items = Enum.map(list, fn item -> item[key_name] end)

      query_without_goal =
        query
        |> Query.put_filter(filter_name, {:member, items})
        |> Query.remove_goal()

      res_without_goal =
        Stats.breakdown(site, query_without_goal, filter_name, [:visitors], pagination)

      list
      |> add_cr(res_without_goal, key_name)
    else
      list
    end
  end

  defp to_csv(list, headers) do
    list
    |> Enum.map(fn row -> Enum.map(headers, &row[&1]) end)
    |> (fn res -> [headers | res] end).()
    |> CSV.encode()
    |> Enum.join()
  end

  defp get_country(code) do
    case Location.get_country(code) do
      nil ->
        Sentry.capture_message("Could not find country info", extra: %{code: code})

        %Location.Country{
          alpha_2: code,
          alpha_3: "N/A",
          name: code,
          flag: nil
        }

      country ->
        country
    end
  end
end
