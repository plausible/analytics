defmodule PlausibleWeb.Api.StatsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler

  alias Plausible.Stats
  alias Plausible.Stats.{Query, Comparisons}
  alias Plausible.Stats.Filters.LegacyDashboardFilterParser
  alias PlausibleWeb.Api.Helpers, as: H

  require Logger

  @revenue_metrics on_ee(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])
  @not_set "(not set)"

  plug(:date_validation_plug)

  @doc """
  Returns a time-series based on given parameters.

  ## Parameters

  This API accepts the following parameters:

    * `period` - x-axis of the graph, e.g. `12mo`, `day`, `custom`.

    * `metric` - y-axis of the graph, e.g. `visits`, `visitors`, `pageviews`.
      See the Stats API ["Metrics"](https://plausible.io/docs/stats-api#metrics)
      section for more details. Defaults to `visitors`.

    * `interval` - granularity of the time-series data. You can think of it as
      a `GROUP BY` clause. Possible values are `minute`, `hour`, `date`, `week`,
      and `month`. The default depends on the `period` parameter. Check
      `Plausible.Query.from/2` for each default.

    * `filters` - optional filters to drill down data. See the Stats API
      ["Filtering"](https://plausible.io/docs/stats-api#filtering) section for
      more details.

    * `with_imported` - boolean indicating whether to include Google Analytics
      imported data or not. Defaults to `false`.

  Full example:
  ```elixir
  %{
    "from" => "2021-09-06",
    "interval" => "month",
    "metric" => "visitors",
    "period" => "custom",
    "to" => "2021-12-13"
  }
  ```

  ## Response

  Returns a map with the following keys:

    * `plot` - list of values for the requested metric representing the y-axis
      of the graph.

    * `labels` - list of date times representing the x-axis of the graph.

    * `present_index` - index of the element representing the current date in
      `labels` and `plot` lists.

    * `interval` - the interval used for querying.

    * `includes_imported` - boolean indicating whether imported data
      was queried or not.

    * `imports_exist` - boolean indicating whether there are any completed
      imports for a given site or not.

    * `full_intervals` - map of dates indicating whether the interval has been
      cut off by the requested date range or not. For example, if looking at a
      month week-by-week, some weeks may be cut off by the month boundaries.
      It's useful to adjust the graph display slightly in case the interval is
      not 'full' so that the user understands why the numbers might be lower for
      those partial periods.

  Full example:
  ```elixir
  %{
    "full_intervals" => %{
      "2021-09-01" => false,
      "2021-10-01" => true,
      "2021-11-01" => true,
      "2021-12-01" => false
    },
    "imports_exist" => false,
    "interval" => "month",
    "labels" => ["2021-09-01", "2021-10-01", "2021-11-01", "2021-12-01"],
    "plot" => [0, 0, 0, 0],
    "present_index" => nil,
    "includes_imported" => false
  }
  ```

  """
  def main_graph(conn, params) do
    site = conn.assigns[:site]

    with {:ok, dates} <- parse_date_params(params),
         :ok <- validate_interval(params),
         :ok <- validate_interval_granularity(site, params, dates),
         query = Query.from(site, params, debug_metadata(conn)),
         {:ok, metric} <- parse_and_validate_graph_metric(params, query) do
      timeseries_query =
        if query.period == "realtime" do
          %Query{query | period: "30m"}
        else
          query
        end

      timeseries_result = Stats.timeseries(site, timeseries_query, [metric])

      comparison_opts = parse_comparison_opts(params)

      {comparison_query, comparison_result} =
        case Comparisons.compare(site, query, params["comparison"], comparison_opts) do
          {:ok, comparison_query} ->
            {comparison_query, Stats.timeseries(site, comparison_query, [metric])}

          {:error, :not_supported} ->
            {nil, nil}
        end

      labels = label_timeseries(timeseries_result, comparison_result)
      present_index = present_index_for(site, query, labels)
      full_intervals = build_full_intervals(query, labels)

      json(conn, %{
        metric: metric,
        plot: plot_timeseries(timeseries_result, metric),
        labels: labels,
        comparison_plot: comparison_result && plot_timeseries(comparison_result, metric),
        comparison_labels: comparison_result && label_timeseries(comparison_result, nil),
        present_index: present_index,
        interval: query.interval,
        includes_imported: includes_imported?(query, comparison_query),
        imports_exist: site.complete_import_ids != [],
        full_intervals: full_intervals
      })
    else
      {:error, message} when is_binary(message) -> bad_request(conn, message)
    end
  end

  defp plot_timeseries(timeseries, metric) do
    Enum.map(timeseries, fn row ->
      case row[metric] do
        nil -> 0
        %Money{} = money -> Decimal.to_float(money.amount)
        value -> value
      end
    end)
  end

  defp label_timeseries(main_result, nil) do
    Enum.map(main_result, & &1.date)
  end

  @blank_value "__blank__"
  defp label_timeseries(main_result, comparison_result) do
    blanks_to_fill = Enum.count(comparison_result) - Enum.count(main_result)

    if blanks_to_fill > 0 do
      blanks = List.duplicate(@blank_value, blanks_to_fill)
      Enum.map(main_result, & &1.date) ++ blanks
    else
      Enum.map(main_result, & &1.date)
    end
  end

  defp build_full_intervals(%{interval: "week", date_range: date_range}, labels) do
    build_intervals(labels, date_range, &Timex.beginning_of_week/1, &Timex.end_of_week/1)
  end

  defp build_full_intervals(%{interval: "month", date_range: date_range}, labels) do
    build_intervals(labels, date_range, &Timex.beginning_of_month/1, &Timex.end_of_month/1)
  end

  defp build_full_intervals(_query, _labels) do
    nil
  end

  def build_intervals(labels, date_range, start_fn, end_fn) do
    for label <- labels, into: %{} do
      case Date.from_iso8601(label) do
        {:ok, date} ->
          interval_start = start_fn.(date)
          interval_end = end_fn.(date)

          within_interval? =
            Enum.member?(date_range, interval_start) && Enum.member?(date_range, interval_end)

          {label, within_interval?}

        _ ->
          {label, false}
      end
    end
  end

  def top_stats(conn, params) do
    site = conn.assigns[:site]

    query = Query.from(site, params, debug_metadata(conn))

    comparison_opts = parse_comparison_opts(params)

    comparison_query =
      case Stats.Comparisons.compare(site, query, params["comparison"], comparison_opts) do
        {:ok, query} -> query
        {:error, _cause} -> nil
      end

    {top_stats, sample_percent} = fetch_top_stats(site, query, comparison_query)

    json(conn, %{
      top_stats: top_stats,
      interval: query.interval,
      sample_percent: sample_percent,
      with_imported_switch: with_imported_switch_info(query, comparison_query),
      includes_imported: includes_imported?(query, comparison_query),
      imports_exist: site.complete_import_ids != [],
      comparing_from: comparison_query && comparison_query.date_range.first,
      comparing_to: comparison_query && comparison_query.date_range.last,
      from: query.date_range.first,
      to: query.date_range.last
    })
  end

  defp with_imported_switch_info(%Query{period: "realtime"}, _) do
    %{visible: false, togglable: false, tooltip_msg: nil}
  end

  defp with_imported_switch_info(query, nil) do
    with_imported_switch_info(query.skip_imported_reason)
  end

  defp with_imported_switch_info(query, comparison_query) do
    case {query.skip_imported_reason, comparison_query.skip_imported_reason} do
      {:out_of_range, nil} -> with_imported_switch_info(nil)
      {:out_of_range, :not_requested} -> with_imported_switch_info(:not_requested)
      {reason, _} -> with_imported_switch_info(reason)
    end
  end

  defp with_imported_switch_info(skip_reason) do
    case skip_reason do
      reason when reason in [:no_imported_data, :out_of_range] ->
        %{visible: false, togglable: false, tooltip_msg: nil}

      :unsupported_query ->
        %{visible: true, togglable: false, tooltip_msg: "Imported data cannot be included"}

      :not_requested ->
        %{visible: true, togglable: true, tooltip_msg: "Click to include imported data"}

      nil ->
        %{visible: true, togglable: true, tooltip_msg: "Click to exclude imported data"}
    end
  end

  defp present_index_for(site, query, dates) do
    case query.interval do
      "hour" ->
        current_date =
          Timex.now(site.timezone)
          |> Calendar.strftime("%Y-%m-%d %H:00:00")

        Enum.find_index(dates, &(&1 == current_date))

      "date" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> Date.to_string()

        Enum.find_index(dates, &(&1 == current_date))

      "week" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> date_or_weekstart(query)
          |> Date.to_string()

        Enum.find_index(dates, &(&1 == current_date))

      "month" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> Timex.beginning_of_month()
          |> Date.to_string()

        Enum.find_index(dates, &(&1 == current_date))

      "minute" ->
        current_date =
          Timex.now(site.timezone)
          |> Calendar.strftime("%Y-%m-%d %H:%M:00")

        Enum.find_index(dates, &(&1 == current_date))
    end
  end

  defp date_or_weekstart(date, query) do
    weekstart = Timex.beginning_of_week(date)

    if Enum.member?(query.date_range, weekstart) do
      weekstart
    else
      date
    end
  end

  defp fetch_top_stats(site, query, comparison_query) do
    goal_filter = Query.get_filter(query, "event:goal")

    cond do
      query.period == "realtime" && goal_filter ->
        fetch_goal_realtime_top_stats(site, query, comparison_query)

      query.period == "realtime" ->
        fetch_realtime_top_stats(site, query, comparison_query)

      goal_filter ->
        fetch_goal_top_stats(site, query, comparison_query)

      true ->
        fetch_other_top_stats(site, query, comparison_query)
    end
  end

  defp fetch_goal_realtime_top_stats(site, query, _comparison_query) do
    query_30m = %Query{query | period: "30m"}

    %{
      visitors: %{value: unique_conversions},
      events: %{value: total_conversions}
    } = Stats.aggregate(site, query_30m, [:visitors, :events])

    stats = [
      %{
        name: "Current visitors",
        value: Stats.current_visitors(site)
      },
      %{
        name: "Unique conversions (last 30 min)",
        graph_metric: :visitors,
        value: unique_conversions
      },
      %{
        name: "Total conversions (last 30 min)",
        graph_metric: :events,
        value: total_conversions
      }
    ]

    {stats, 100}
  end

  defp fetch_realtime_top_stats(site, query, _comparison_query) do
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
        graph_metric: :visitors,
        value: visitors
      },
      %{
        name: "Pageviews (last 30 min)",
        graph_metric: :pageviews,
        value: pageviews
      }
    ]

    {stats, 100}
  end

  defp fetch_goal_top_stats(site, query, comparison_query) do
    metrics =
      [:total_visitors, :visitors, :events, :conversion_rate] ++ @revenue_metrics

    results = Stats.aggregate(site, query, metrics)
    comparison = if comparison_query, do: Stats.aggregate(site, comparison_query, metrics)

    [
      top_stats_entry(results, comparison, "Unique visitors", :total_visitors),
      top_stats_entry(results, comparison, "Unique conversions", :visitors, graphable?: true),
      top_stats_entry(results, comparison, "Total conversions", :events, graphable?: true),
      on_ee do
        top_stats_entry(results, comparison, "Average revenue", :average_revenue,
          formatter: &format_money/1,
          graphable?: true
        )
      end,
      on_ee do
        top_stats_entry(results, comparison, "Total revenue", :total_revenue,
          formatter: &format_money/1,
          graphable?: true
        )
      end,
      top_stats_entry(results, comparison, "Conversion rate", :conversion_rate, graphable?: true)
    ]
    |> Enum.reject(&is_nil/1)
    |> then(&{&1, 100})
  end

  defp fetch_other_top_stats(site, query, comparison_query) do
    page_filter? = Query.get_filter(query, "event:page")

    metrics = [:visitors, :visits, :pageviews, :sample_percent]

    metrics =
      cond do
        page_filter? && query.include_imported -> metrics
        page_filter? -> metrics ++ [:bounce_rate, :time_on_page]
        true -> metrics ++ [:views_per_visit, :bounce_rate, :visit_duration]
      end

    current_results = Stats.aggregate(site, query, metrics)
    prev_results = comparison_query && Stats.aggregate(site, comparison_query, metrics)

    stats =
      [
        top_stats_entry(current_results, prev_results, "Unique visitors", :visitors,
          graphable?: true
        ),
        top_stats_entry(current_results, prev_results, "Total visits", :visits, graphable?: true),
        top_stats_entry(current_results, prev_results, "Total pageviews", :pageviews,
          graphable?: true
        ),
        top_stats_entry(current_results, prev_results, "Views per visit", :views_per_visit,
          graphable?: true
        ),
        top_stats_entry(current_results, prev_results, "Bounce rate", :bounce_rate,
          graphable?: true
        ),
        top_stats_entry(current_results, prev_results, "Visit duration", :visit_duration,
          graphable?: true
        ),
        top_stats_entry(current_results, prev_results, "Time on page", :time_on_page,
          formatter: fn
            nil -> 0
            value -> value
          end
        )
      ]
      |> Enum.filter(& &1)

    {stats, current_results[:sample_percent][:value]}
  end

  defp top_stats_entry(current_results, prev_results, name, key, opts \\ []) do
    if current_results[key] do
      formatter = Keyword.get(opts, :formatter, & &1)
      value = get_in(current_results, [key, :value])

      %{name: name, value: formatter.(value)}
      |> maybe_put_graph_metric(opts, key)
      |> maybe_put_comparison(prev_results, key, value, formatter)
    end
  end

  defp maybe_put_graph_metric(entry, opts, key) do
    if Keyword.get(opts, :graphable?) do
      entry |> Map.put(:graph_metric, key)
    else
      entry
    end
  end

  defp maybe_put_comparison(entry, prev_results, key, value, formatter) do
    if prev_results do
      prev_value = get_in(prev_results, [key, :value])
      change = Stats.Compare.calculate_change(key, prev_value, value)

      entry
      |> Map.put(:comparison_value, formatter.(prev_value))
      |> Map.put(:change, change)
    else
      entry
    end
  end

  def sources(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:source")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics)

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{source: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  on_ee do
    def funnel(conn, %{"id" => funnel_id} = params) do
      site = Plausible.Repo.preload(conn.assigns.site, :owner)

      with :ok <- Plausible.Billing.Feature.Funnels.check_availability(site.owner),
           query <- Query.from(site, params, debug_metadata(conn)),
           :ok <- validate_funnel_query(query),
           {funnel_id, ""} <- Integer.parse(funnel_id),
           {:ok, funnel} <- Stats.funnel(site, query, funnel_id) do
        json(conn, funnel)
      else
        {:error, {:invalid_funnel_query, due_to}} ->
          bad_request(
            conn,
            "We are unable to show funnels when the dashboard is filtered by #{due_to}",
            %{
              level: :normal
            }
          )

        {:error, :funnel_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Funnel not found"})
          |> halt()

        {:error, :upgrade_required} ->
          H.payment_required(
            conn,
            "#{Plausible.Billing.Feature.Funnels.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
          )

        _ ->
          bad_request(conn, "There was an error with your request")
      end
    end

    defp validate_funnel_query(query) do
      cond do
        Query.get_filter(query, "event:goal") ->
          {:error, {:invalid_funnel_query, "goals"}}

        Query.get_filter(query, "event:page") ->
          {:error, {:invalid_funnel_query, "pages"}}

        query.period == "realtime" ->
          {:error, {:invalid_funnel_query, "realtime period"}}

        true ->
          :ok
      end
    end
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_medium")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{utm_medium: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def utm_campaigns(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_campaign")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{utm_campaign: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def utm_contents(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_content")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{utm_content: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def utm_terms(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_term")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{utm_term: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def utm_sources(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_source")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{utm_source: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def referrers(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:referrer")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:bounce_rate, :visit_duration])

    res =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{referrer: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site]

    query = Query.from(site, params, debug_metadata(conn))

    user_id = get_session(conn, :current_user_id)
    is_admin = user_id && Plausible.Sites.has_admin_access?(user_id, site)

    pagination = {
      to_int(params["limit"], 9),
      to_int(params["page"], 0)
    }

    search = params["search"] || ""

    not_configured_error_payload =
      %{
        error: "The site is not connected to Google Search Keywords",
        reason: :not_configured,
        is_admin: is_admin
      }

    unsupported_filters_error_payload = %{
      error:
        "Unable to fetch keyword data from Search Console because it does not support the current set of filters",
      reason: :unsupported_filters
    }

    case google_api().fetch_stats(site, query, pagination, search) do
      {:error, :google_property_not_configured} ->
        conn
        |> put_status(422)
        |> json(not_configured_error_payload)

      {:error, :unsupported_filters} ->
        conn
        |> put_status(422)
        |> json(unsupported_filters_error_payload)

      {:ok, terms} ->
        json(conn, %{results: terms})

      {:error, error} ->
        Logger.error("Plausible.Google.API.fetch_stats failed with error: `#{inspect(error)}`")

        conn
        |> put_status(502)
        |> json(not_configured_error_payload)
    end
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:referrer")

    referrer_filter = LegacyDashboardFilterParser.filter_value("visit:source", referrer)

    query =
      Query.from(site, params, debug_metadata(conn))
      |> Query.add_filter(referrer_filter)

    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics)

    referrers =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{referrer: :name})

    json(conn, %{
      results: referrers,
      skip_imported_reason: query.skip_imported_reason
    })
  end

  def pages(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "event:page")
    query = Query.from(site, params, debug_metadata(conn))

    extra_metrics =
      if params["detailed"],
        do: [:pageviews, :bounce_rate, :time_on_page],
        else: []

    metrics = breakdown_metrics(query, extra_metrics)
    pagination = parse_pagination(params)

    pages =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{page: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        pages
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        pages |> to_csv([:name, :visitors, :pageviews, :bounce_rate, :time_on_page])
      end
    else
      json(conn, %{
        results: pages,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:entry_page")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:visits, :visit_duration])

    entry_pages =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{entry_page: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        to_csv(entry_pages, [:name, :visitors, :conversion_rate], [
          :name,
          :conversions,
          :conversion_rate
        ])
      else
        to_csv(entry_pages, [:name, :visitors, :visits, :visit_duration], [
          :name,
          :unique_entrances,
          :total_entrances,
          :visit_duration
        ])
      end
    else
      json(conn, %{
        results: entry_pages,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def exit_pages(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:exit_page")
    query = Query.from(site, params, debug_metadata(conn))
    {limit, page} = parse_pagination(params)
    metrics = breakdown_metrics(query, [:visits])

    exit_pages =
      Stats.breakdown(site, query, metrics, {limit, page})
      |> add_exit_rate(site, query, limit)
      |> transform_keys(%{exit_page: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        to_csv(exit_pages, [:name, :visitors, :conversion_rate], [
          :name,
          :conversions,
          :conversion_rate
        ])
      else
        to_csv(exit_pages, [:name, :visitors, :visits, :exit_rate], [
          :name,
          :unique_exits,
          :total_exits,
          :exit_rate
        ])
      end
    else
      json(conn, %{
        results: exit_pages,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  defp add_exit_rate(breakdown_results, site, query, limit) do
    if Query.has_event_filters?(query) do
      breakdown_results
    else
      pages = Enum.map(breakdown_results, & &1[:exit_page])

      total_pageviews_query =
        query
        |> Query.remove_filters(["visit:exit_page"])
        |> Query.add_filter([:is, "event:page", pages])
        |> Query.set(dimensions: ["event:page"])

      total_pageviews =
        Stats.breakdown(site, total_pageviews_query, [:pageviews], {limit, 1})

      Enum.map(breakdown_results, fn result ->
        exit_rate =
          case Enum.find(total_pageviews, &(&1[:page] == result[:exit_page])) do
            %{pageviews: pageviews} ->
              Float.floor(result[:visits] / pageviews * 100)

            nil ->
              nil
          end

        Map.put(result, :exit_rate, exit_rate)
      end)
    end
  end

  def countries(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:country")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query, [:percentage])

    countries =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{country: :code})

    if params["csv"] do
      countries =
        countries
        |> Enum.map(fn country ->
          country_info = get_country(country[:code])
          Map.put(country, :name, country_info.name)
        end)

      if Query.get_filter(query, "event:goal") do
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

      json(conn, %{
        results: countries,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def regions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:region")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query)

    regions =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{region: :code})
      |> Enum.map(fn region ->
        region_entry = Location.get_subdivision(region[:code])

        if region_entry do
          country_entry = get_country(region_entry.country_code)
          Map.merge(region, %{name: region_entry.name, country_flag: country_entry.flag})
        else
          Logger.warning("Could not find region info - code: #{inspect(region[:code])}")
          Map.merge(region, %{name: region[:code]})
        end
      end)

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        regions
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        regions |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: regions,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def cities(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:city")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)
    metrics = breakdown_metrics(query)

    cities =
      Stats.breakdown(site, query, metrics, pagination)
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
          Logger.warning("Could not find city info - code: #{inspect(city[:code])}")

          Map.merge(city, %{name: "N/A"})
        end
      end)

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        cities
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        cities |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: cities,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:browser")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics ++ [:percentage])

    browsers =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{browser: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        browsers
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        browsers |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: browsers,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def browser_versions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:browser_version")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics ++ [:percentage])

    results =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{browser_version: :version})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        results
        |> transform_keys(%{browser: :name, visitors: :conversions})
        |> to_csv([:name, :version, :conversions, :conversion_rate])
      else
        results
        |> transform_keys(%{browser: :name})
        |> to_csv([:name, :version, :visitors])
      end
    else
      results =
        if params["detailed"] do
          transform_keys(results, %{version: :name})
        else
          Enum.map(results, &put_combined_name_with_version(&1, :browser))
        end

      json(conn, %{
        results: results,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:os")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics ++ [:percentage])

    systems =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{os: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        systems
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        systems |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: systems,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def operating_system_versions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:os_version")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics ++ [:percentage])

    results =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{os_version: :version})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        results
        |> transform_keys(%{os: :name, visitors: :conversions})
        |> to_csv([:name, :version, :conversions, :conversion_rate])
      else
        results
        |> transform_keys(%{os: :name})
        |> to_csv([:name, :version, :visitors])
      end
    else
      results =
        if params["detailed"] do
          transform_keys(results, %{version: :name})
        else
          Enum.map(results, &put_combined_name_with_version(&1, :os))
        end

      json(conn, %{
        results: results,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:device")
    query = Query.from(site, params, debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics = breakdown_metrics(query, extra_metrics ++ [:percentage])

    sizes =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{device: :name})

    if params["csv"] do
      if Query.get_filter(query, "event:goal") do
        sizes
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        sizes |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: sizes,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def conversions(conn, params) do
    pagination = parse_pagination(params)
    site = Plausible.Repo.preload(conn.assigns.site, :goals)
    params = Map.put(params, "property", "event:goal")
    query = Query.from(site, params, debug_metadata(conn))

    query =
      if query.period == "realtime" do
        %Query{query | period: "30m"}
      else
        query
      end

    metrics = [:visitors, :events, :conversion_rate] ++ @revenue_metrics

    conversions =
      site
      |> Stats.breakdown(query, metrics, pagination)
      |> transform_keys(%{goal: :name})
      |> Enum.map(fn goal ->
        goal
        |> Enum.map(&format_revenue_metric/1)
        |> Map.new()
      end)

    if params["csv"] do
      to_csv(conversions, [:name, :visitors, :events], [
        :name,
        :unique_conversions,
        :total_conversions
      ])
    else
      json(conn, %{
        results: conversions,
        skip_imported_reason: query.skip_imported_reason
      })
    end
  end

  def custom_prop_values(conn, params) do
    site = Plausible.Repo.preload(conn.assigns.site, :owner)
    prop_key = Map.fetch!(params, "prop_key")

    case Plausible.Props.ensure_prop_key_accessible(prop_key, site.owner) do
      :ok ->
        json(conn, breakdown_custom_prop_values(conn, site, params))

      {:error, :upgrade_required} ->
        H.payment_required(
          conn,
          "#{Plausible.Billing.Feature.Props.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
        )
    end
  end

  def all_custom_prop_values(conn, params) do
    site = conn.assigns.site
    query = Query.from(site, params, debug_metadata(conn))

    prop_names = Plausible.Stats.CustomProps.fetch_prop_names(site, query)

    prop_names =
      if Plausible.Billing.Feature.Props.enabled?(site) do
        prop_names
      else
        prop_names |> Enum.filter(&(&1 in Plausible.Props.internal_keys()))
      end

    if not Enum.empty?(prop_names) do
      values =
        prop_names
        |> Enum.map(fn prop_key ->
          breakdown_custom_prop_values(conn, site, Map.put(params, "prop_key", prop_key))
          |> Map.get(:results)
          |> Enum.map(&Map.put(&1, :property, prop_key))
          |> transform_keys(%{:name => :value})
        end)
        |> Enum.concat()

      percent_or_cr =
        if Query.get_filter(query, "event:goal"),
          do: :conversion_rate,
          else: :percentage

      to_csv(values, [:property, :value, :visitors, :events, percent_or_cr])
    end
  end

  defp breakdown_custom_prop_values(conn, site, %{"prop_key" => prop_key} = params) do
    pagination = parse_pagination(params)
    prefixed_prop = "event:props:" <> prop_key

    params = Map.put(params, "property", prefixed_prop)

    query = Query.from(site, params, debug_metadata(conn))

    metrics =
      if Query.get_filter(query, "event:goal") do
        [:visitors, :events, :conversion_rate] ++ @revenue_metrics
      else
        [:visitors, :events, :percentage] ++ @revenue_metrics
      end

    props =
      Stats.breakdown(site, query, metrics, pagination)
      |> transform_keys(%{prop_key => :name})
      |> Enum.map(fn entry ->
        Enum.map(entry, &format_revenue_metric/1)
        |> Map.new()
      end)

    %{results: props, skip_imported_reason: query.skip_imported_reason}
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    json(conn, Stats.current_visitors(site))
  end

  defp google_api(), do: Application.fetch_env!(:plausible, :google_api)

  def filter_suggestions(conn, params) do
    site = conn.assigns[:site]

    query = Query.from(site, params, debug_metadata(conn))

    json(
      conn,
      Stats.filter_suggestions(site, query, params["filter_name"], params["q"])
    )
  end

  defp transform_keys(result, keys_to_replace) when is_map(result) do
    for {key, val} <- result, do: {Map.get(keys_to_replace, key, key), val}, into: %{}
  end

  defp transform_keys(results, keys_to_replace) when is_list(results) do
    Enum.map(results, &transform_keys(&1, keys_to_replace))
  end

  defp parse_pagination(params) do
    limit = to_int(params["limit"], 9)
    page = to_int(params["page"], 1)
    {limit, page}
  end

  defp to_int(string, default) when is_binary(string) do
    case Integer.parse(string) do
      {i, ""} when is_integer(i) ->
        i

      _ ->
        default
    end
  end

  defp to_int(_, default), do: default

  defp to_csv(list, columns), do: to_csv(list, columns, columns)

  defp to_csv(list, columns, column_names) do
    list
    |> Enum.map(fn row -> Enum.map(columns, &row[&1]) end)
    |> (fn res -> [column_names | res] end).()
    |> NimbleCSV.RFC4180.dump_to_iodata()
  end

  defp get_country(code) do
    case Location.get_country(code) do
      nil ->
        Logger.warning("Could not find country info - code: #{inspect(code)}")

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

  defp date_validation_plug(conn, _opts) do
    case parse_date_params(conn.params) do
      {:ok, _dates} -> conn
      {:error, message} when is_binary(message) -> bad_request(conn, message)
    end
  end

  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Date.from_iso8601(value) do
        {:ok, date} ->
          {:cont, {:ok, Map.put(acc, key, date)}}

        _ ->
          {:halt,
           {:error,
            "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"}}
      end
    end)
  end

  defp validate_interval(params) do
    with %{"interval" => interval} <- params,
         true <- Plausible.Stats.Interval.valid?(interval) do
      :ok
    else
      %{} ->
        :ok

      false ->
        values = Enum.join(Plausible.Stats.Interval.list(), ", ")
        {:error, "Invalid value for interval. Accepted values are: #{values}"}
    end
  end

  defp validate_interval_granularity(site, params, dates) do
    case params do
      %{"interval" => interval, "period" => "custom", "from" => _, "to" => _} ->
        if Plausible.Stats.Interval.valid_for_period?("custom", interval,
             site: site,
             from: dates["from"],
             to: dates["to"]
           ) do
          :ok
        else
          {:error,
           "Invalid combination of interval and period. Custom ranges over 12 months must come with greater granularity, e.g. `period=custom,interval=week`"}
        end

      %{"interval" => interval, "period" => period} ->
        if Plausible.Stats.Interval.valid_for_period?(period, interval, site: site) do
          :ok
        else
          {:error,
           "Invalid combination of interval and period. Interval must be smaller than the selected period, e.g. `period=day,interval=minute`"}
        end

      _ ->
        :ok
    end
  end

  defp parse_and_validate_graph_metric(params, query) do
    metric =
      case params["metric"] do
        nil -> :visitors
        "conversions" -> :visitors
        m -> Plausible.Stats.Metrics.from_string!(m)
      end

    requires_goal_filter? = metric in [:conversion_rate, :events]

    if requires_goal_filter? and !Query.get_filter(query, "event:goal") do
      {:error, "Metric `#{metric}` can only be queried with a goal filter"}
    else
      {:ok, metric}
    end
  end

  defp bad_request(conn, message, extra \\ %{}) do
    payload = Map.merge(extra, %{error: message})

    conn
    |> put_status(400)
    |> json(payload)
    |> halt()
  end

  defp parse_comparison_opts(params) do
    [
      from: params["compare_from"],
      to: params["compare_to"],
      match_day_of_week?: params["match_day_of_week"] == "true"
    ]
  end

  defp includes_imported?(source_query, comparison_query) do
    cond do
      source_query.include_imported -> true
      comparison_query && comparison_query.include_imported -> true
      true -> false
    end
  end

  on_ee do
    defdelegate format_revenue_metric(metric_value), to: PlausibleWeb.Controllers.API.Revenue
    defdelegate format_money(money), to: PlausibleWeb.Controllers.API.Revenue
  else
    defp format_revenue_metric({metric, value}) do
      {metric, value}
    end
  end

  defp breakdown_metrics(query, extra_metrics \\ []) do
    if Query.get_filter(query, "event:goal") do
      [:visitors, :conversion_rate, :total_visitors]
    else
      [:visitors] ++ extra_metrics
    end
  end

  def put_combined_name_with_version(row, name_key) do
    name =
      case {row[name_key], row.version} do
        {@not_set, @not_set} -> @not_set
        {browser_or_os, version} -> "#{browser_or_os} #{version}"
      end

    Map.put(row, :name, name)
  end
end
