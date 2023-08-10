defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats
  alias Plausible.Stats.{Query, Filters, Comparisons, CustomProps}

  require Logger

  plug(:validate_common_input)

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

    * `with_imported` - boolean indicating whether the Google Analytics data
      was queried or not.

    * `imported_source` - the source of the imported data, when applicable.
      Currently only Google Analytics is supported.

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
    "imported_source" => nil,
    "interval" => "month",
    "labels" => ["2021-09-01", "2021-10-01", "2021-11-01", "2021-12-01"],
    "plot" => [0, 0, 0, 0],
    "present_index" => nil,
    "with_imported" => false
  }
  ```

  """
  def main_graph(conn, params) do
    site = conn.assigns[:site]

    with :ok <- validate_params(site, params) do
      query = Query.from(site, params) |> Filters.add_prefix()

      selected_metric =
        if !params["metric"] || params["metric"] == "conversions" do
          :visitors
        else
          String.to_existing_atom(params["metric"])
        end

      timeseries_query =
        if query.period == "realtime" do
          %Query{query | period: "30m"}
        else
          query
        end

      timeseries_result = Stats.timeseries(site, timeseries_query, [selected_metric])

      comparison_opts = parse_comparison_opts(params)

      {comparison_query, comparison_result} =
        case Comparisons.compare(site, query, params["comparison"], comparison_opts) do
          {:ok, comparison_query} ->
            {comparison_query, Stats.timeseries(site, comparison_query, [selected_metric])}

          {:error, :not_supported} ->
            {nil, nil}
        end

      labels = label_timeseries(timeseries_result, comparison_result)
      present_index = present_index_for(site, query, labels)
      full_intervals = build_full_intervals(query, labels)

      json(conn, %{
        plot: plot_timeseries(timeseries_result, selected_metric),
        labels: labels,
        comparison_plot: comparison_result && plot_timeseries(comparison_result, selected_metric),
        comparison_labels: comparison_result && label_timeseries(comparison_result, nil),
        present_index: present_index,
        interval: query.interval,
        with_imported: with_imported?(query, comparison_query),
        imported_source: site.imported_data && site.imported_data.source,
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

  defp build_full_intervals(%{interval: "week", date_range: range}, labels) do
    for label <- labels, into: %{} do
      interval_start = Timex.beginning_of_week(label)
      interval_end = Timex.end_of_week(label)

      within_interval? = Enum.member?(range, interval_start) && Enum.member?(range, interval_end)

      {label, within_interval?}
    end
  end

  defp build_full_intervals(%{interval: "month", date_range: range}, labels) do
    for label <- labels, into: %{} do
      interval_start = Timex.beginning_of_month(label)
      interval_end = Timex.end_of_month(label)

      within_interval? = Enum.member?(range, interval_start) && Enum.member?(range, interval_end)

      {label, within_interval?}
    end
  end

  defp build_full_intervals(_query, _labels) do
    nil
  end

  def top_stats(conn, params) do
    site = conn.assigns[:site]

    with :ok <- validate_params(site, params) do
      query = Query.from(site, params) |> Filters.add_prefix()

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
        with_imported: with_imported?(query, comparison_query),
        imported_source: site.imported_data && site.imported_data.source,
        comparing_from: comparison_query && comparison_query.date_range.first,
        comparing_to: comparison_query && comparison_query.date_range.last,
        from: query.date_range.first,
        to: query.date_range.last
      })
    else
      {:error, message} when is_binary(message) -> bad_request(conn, message)
    end
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

      "week" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> date_or_weekstart(query)

        Enum.find_index(dates, &(&1 == current_date))

      "month" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.to_date()
          |> Timex.beginning_of_month()

        Enum.find_index(dates, &(&1 == current_date))

      "minute" ->
        current_date =
          Timex.now(site.timezone)
          |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}:00")

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

  defp fetch_top_stats(
         site,
         %Query{period: "realtime", filters: %{"event:goal" => _goal}} = query,
         _comparison_query
       ) do
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
        value: unique_conversions
      },
      %{
        name: "Total conversions (last 30 min)",
        value: total_conversions
      }
    ]

    {stats, 100}
  end

  defp fetch_top_stats(site, %Query{period: "realtime"} = query, _comparison_query) do
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

  defp fetch_top_stats(site, %Query{filters: %{"event:goal" => _}} = query, comparison_query) do
    query_without_filters = Query.remove_event_filters(query, [:goal, :props])
    metrics = [:visitors, :events, :average_revenue, :total_revenue]

    results_without_filters =
      site
      |> Stats.aggregate(query_without_filters, [:visitors])
      |> transform_keys(%{visitors: :unique_visitors})

    results =
      site
      |> Stats.aggregate(query, metrics)
      |> transform_keys(%{visitors: :converted_visitors, events: :completions})
      |> Map.merge(results_without_filters)

    comparison =
      if comparison_query do
        comparison_query_without_filters =
          Query.remove_event_filters(comparison_query, [:goal, :props])

        comparison_without_filters =
          site
          |> Stats.aggregate(comparison_query_without_filters, [:visitors])
          |> transform_keys(%{visitors: :unique_visitors})

        site
        |> Stats.aggregate(comparison_query, metrics)
        |> transform_keys(%{visitors: :converted_visitors, events: :completions})
        |> Map.merge(comparison_without_filters)
      end

    conversion_rate = %{
      cr: %{value: calculate_cr(results.unique_visitors.value, results.converted_visitors.value)}
    }

    comparison_conversion_rate =
      if comparison do
        value =
          calculate_cr(comparison.unique_visitors.value, comparison.converted_visitors.value)

        %{cr: %{value: value}}
      else
        nil
      end

    [
      top_stats_entry(results, comparison, "Unique visitors", :unique_visitors),
      top_stats_entry(results, comparison, "Unique conversions", :converted_visitors),
      top_stats_entry(results, comparison, "Total conversions", :completions),
      top_stats_entry(results, comparison, "Average revenue", :average_revenue, &format_money/1),
      top_stats_entry(results, comparison, "Total revenue", :total_revenue, &format_money/1),
      top_stats_entry(conversion_rate, comparison_conversion_rate, "Conversion rate", :cr)
    ]
    |> Enum.reject(&is_nil/1)
    |> then(&{&1, 100})
  end

  defp fetch_top_stats(site, query, comparison_query) do
    metrics =
      if query.filters["event:page"] do
        [
          :visitors,
          :visits,
          :pageviews,
          :bounce_rate,
          :time_on_page,
          :sample_percent
        ]
      else
        [
          :visitors,
          :visits,
          :pageviews,
          :views_per_visit,
          :bounce_rate,
          :visit_duration,
          :sample_percent
        ]
      end

    current_results = Stats.aggregate(site, query, metrics)
    prev_results = comparison_query && Stats.aggregate(site, comparison_query, metrics)

    stats =
      [
        top_stats_entry(current_results, prev_results, "Unique visitors", :visitors),
        top_stats_entry(current_results, prev_results, "Total visits", :visits),
        top_stats_entry(current_results, prev_results, "Total pageviews", :pageviews),
        top_stats_entry(current_results, prev_results, "Views per visit", :views_per_visit),
        top_stats_entry(current_results, prev_results, "Bounce rate", :bounce_rate),
        top_stats_entry(current_results, prev_results, "Visit duration", :visit_duration),
        top_stats_entry(current_results, prev_results, "Time on page", :time_on_page)
      ]
      |> Enum.filter(& &1)

    {stats, current_results[:sample_percent][:value]}
  end

  defp top_stats_entry(current_results, prev_results, name, key, formatter \\ & &1) do
    if current_results[key] do
      value = get_in(current_results, [key, :value])

      if prev_results do
        prev_value = get_in(prev_results, [key, :value])
        change = calculate_change(key, prev_value, value)

        %{
          name: name,
          value: formatter.(value),
          comparison_value: formatter.(prev_value),
          change: change
        }
      else
        %{name: name, value: formatter.(value)}
      end
    end
  end

  defp calculate_change(:bounce_rate, old_count, new_count) do
    if old_count > 0, do: new_count - old_count
  end

  defp calculate_change(_metric, old_count, new_count) do
    percent_change(old_count, new_count)
  end

  defp percent_change(nil, _new_count), do: nil

  defp percent_change(%Money{} = old_count, %Money{} = new_count) do
    old_count = old_count |> Money.to_decimal() |> Decimal.to_float()
    new_count = new_count |> Money.to_decimal() |> Decimal.to_float()
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

    pagination = parse_pagination(params)

    metrics =
      if params["detailed"], do: [:visitors, :bounce_rate, :visit_duration], else: [:visitors]

    res =
      Stats.breakdown(site, query, "visit:source", metrics, pagination)
      |> add_cr(site, query, pagination, :source, "visit:source")
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

  def funnel(conn, %{"id" => funnel_id} = params) do
    site = conn.assigns[:site]

    with :ok <- validate_params(site, params),
         query <- Query.from(site, params) |> Filters.add_prefix(),
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

      _ ->
        bad_request(conn, "There was an error with your request")
    end
  end

  defp validate_funnel_query(query) do
    case query do
      _ when is_map_key(query.filters, "event:goal") ->
        {:error, {:invalid_funnel_query, "goals"}}

      _ when is_map_key(query.filters, "event:page") ->
        {:error, {:invalid_funnel_query, "pages"}}

      _ when query.period == "realtime" ->
        {:error, {:invalid_funnel_query, "realtime period"}}

      _ ->
        :ok
    end
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_medium", metrics, pagination)
      |> add_cr(site, query, pagination, :utm_medium, "visit:utm_medium")
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

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_campaign", metrics, pagination)
      |> add_cr(site, query, pagination, :utm_campaign, "visit:utm_campaign")
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

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_content", metrics, pagination)
      |> add_cr(site, query, pagination, :utm_content, "visit:utm_content")
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

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_term", metrics, pagination)
      |> add_cr(site, query, pagination, :utm_term, "visit:utm_term")
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

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_source", metrics, pagination)
      |> add_cr(site, query, pagination, :utm_source, "visit:utm_source")
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

  def referrers(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:referrer", metrics, pagination)
      |> add_cr(site, query, pagination, :referrer, "visit:referrer")
      |> transform_keys(%{referrer: :name})

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

    user_id = get_session(conn, :current_user_id)
    is_admin = user_id && Plausible.Sites.has_admin_access?(user_id, site)

    case search_terms do
      nil ->
        json(conn, %{not_configured: true, is_admin: is_admin, total_visitors: total_visitors})

      {:ok, terms} ->
        json(conn, %{search_terms: terms, total_visitors: total_visitors})

      {:error, _} ->
        conn
        |> put_status(502)
        |> json(%{
          not_configured: true,
          is_admin: is_admin,
          total_visitors: total_visitors
        })
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
      |> add_cr(site, query, pagination, :referrer, "visit:referrer")
      |> transform_keys(%{referrer: :name})

    json(conn, referrers)
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
      |> add_cr(site, query, pagination, :page, "event:page")
      |> transform_keys(%{page: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
        pages
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        pages |> to_csv([:name, :visitors, :pageviews, :bounce_rate, :time_on_page])
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
      |> add_cr(site, query, pagination, :entry_page, "visit:entry_page")
      |> transform_keys(%{entry_page: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
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
      |> add_cr(site, query, {limit, page}, :exit_page, "visit:exit_page")
      |> add_exit_rate(site, query, limit)
      |> transform_keys(%{exit_page: :name})

    if params["csv"] do
      if Map.has_key?(query.filters, "event:goal") do
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
      json(conn, exit_pages)
    end
  end

  defp add_exit_rate(breakdown_results, site, query, limit) do
    if Query.has_event_filters?(query) do
      breakdown_results
    else
      pages = Enum.map(breakdown_results, & &1[:exit_page])

      total_visits_query =
        Query.put_filter(query, "event:page", {:member, pages})
        |> Query.put_filter("event:name", {:is, "pageview"})

      total_pageviews =
        Stats.breakdown(site, total_visits_query, "event:page", [:pageviews], {limit, 1})

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
    query = site |> Query.from(params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    countries =
      Stats.breakdown(site, query, "visit:country", [:visitors], pagination)
      |> add_cr(site, query, {300, 1}, :country, "visit:country")
      |> transform_keys(%{country: :code})
      |> add_percentages(site, query)

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
    query = site |> Query.from(params) |> Filters.add_prefix()
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
          Logger.warning("Could not find region info - code: #{inspect(region[:code])}")
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
    query = site |> Query.from(params) |> Filters.add_prefix()
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
          Logger.warning("Could not find city info - code: #{inspect(city[:code])}")

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
      |> add_cr(site, query, pagination, :browser, "visit:browser")
      |> transform_keys(%{browser: :name})
      |> add_percentages(site, query)

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
      |> add_cr(site, query, pagination, :browser_version, "visit:browser_version")
      |> transform_keys(%{browser_version: :name})
      |> add_percentages(site, query)

    json(conn, versions)
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    systems =
      Stats.breakdown(site, query, "visit:os", [:visitors], pagination)
      |> add_cr(site, query, pagination, :os, "visit:os")
      |> transform_keys(%{os: :name})
      |> add_percentages(site, query)

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
      |> add_cr(site, query, pagination, :os_version, "visit:os_version")
      |> transform_keys(%{os_version: :name})
      |> add_percentages(site, query)

    json(conn, versions)
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    sizes =
      Stats.breakdown(site, query, "visit:device", [:visitors], pagination)
      |> add_cr(site, query, pagination, :device, "visit:device")
      |> transform_keys(%{device: :name})
      |> add_percentages(site, query)

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

  defp calculate_cr(nil, _converted_visitors), do: nil

  defp calculate_cr(unique_visitors, converted_visitors) do
    if unique_visitors > 0,
      do: Float.round(converted_visitors / unique_visitors * 100, 1),
      else: 0.0
  end

  def conversions(conn, params) do
    pagination = parse_pagination(params)
    site = Plausible.Repo.preload(conn.assigns.site, :goals)
    query = Query.from(site, params) |> Filters.add_prefix()

    query =
      if query.period == "realtime" do
        %Query{query | period: "30m"}
      else
        query
      end

    total_q = Query.remove_event_filters(query, [:goal, :props])

    %{visitors: %{value: total_visitors}} = Stats.aggregate(site, total_q, [:visitors])

    metrics =
      if Enum.any?(site.goals, &Plausible.Goal.revenue?/1) do
        [:visitors, :events, :average_revenue, :total_revenue]
      else
        [:visitors, :events]
      end

    conversions =
      site
      |> Stats.breakdown(query, "event:goal", metrics, pagination)
      |> transform_keys(%{goal: :name})
      |> Enum.map(fn goal ->
        goal
        |> Map.put(:prop_names, CustomProps.props_for_goal(site, query))
        |> Map.put(:conversion_rate, calculate_cr(total_visitors, goal[:visitors]))
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
      json(conn, conversions)
    end
  end

  @revenue_metrics [:average_revenue, :total_revenue]
  defp format_revenue_metric({metric, value}) do
    if metric in @revenue_metrics do
      {metric, format_money(value)}
    else
      {metric, value}
    end
  end

  defp format_money(value) do
    case value do
      %Money{} ->
        %{
          short: Money.to_string!(value, format: :short, fractional_digits: 1),
          long: Money.to_string!(value)
        }

      _any ->
        value
    end
  end

  def custom_prop_values(conn, params) do
    site = conn.assigns[:site]
    props = breakdown_custom_prop_values(site, params)
    json(conn, props)
  end

  def all_custom_prop_values(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    prop_names = Plausible.Stats.CustomProps.fetch_prop_names(site, query)

    values =
      prop_names
      |> Enum.map(fn prop_key ->
        breakdown_custom_prop_values(site, Map.put(params, "prop_key", prop_key))
        |> Enum.map(&Map.put(&1, :property, prop_key))
        |> transform_keys(%{:name => :value})
      end)
      |> Enum.concat()

    percent_or_cr =
      if query.filters["event:goal"],
        do: :conversion_rate,
        else: :percentage

    to_csv(values, [:property, :value, :visitors, :events, percent_or_cr])
  end

  defp breakdown_custom_prop_values(site, %{"prop_key" => prop_key} = params) do
    pagination = parse_pagination(params)
    prefixed_prop = "event:props:" <> prop_key

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Map.put(:include_imported, false)

    metrics =
      if Map.has_key?(query.filters, "event:goal") do
        [:visitors, :events, :average_revenue, :total_revenue]
      else
        [:visitors, :events]
      end

    props =
      Stats.breakdown(site, query, prefixed_prop, metrics, pagination)
      |> transform_keys(%{prop_key => :name})
      |> Enum.map(fn entry ->
        Enum.map(entry, &format_revenue_metric/1)
        |> Map.new()
      end)
      |> add_percentages(site, query)

    if Map.has_key?(query.filters, "event:goal") do
      total_q = Query.remove_event_filters(query, [:goal, :props])

      %{visitors: %{value: total_unique_visitors}} = Stats.aggregate(site, total_q, [:visitors])

      Enum.map(props, fn prop ->
        Map.put(prop, :conversion_rate, calculate_cr(total_unique_visitors, prop.visitors))
      end)
    else
      props
    end
  end

  def prop_breakdown(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    total_q = Query.remove_event_filters(query, [:goal, :props])

    %{:visitors => %{value: unique_visitors}} = Stats.aggregate(site, total_q, [:visitors])

    prop_name = "event:props:" <> params["prop_name"]

    props =
      Stats.breakdown(
        site,
        query,
        prop_name,
        [:visitors, :events, :average_revenue, :total_revenue],
        pagination
      )
      |> transform_keys(%{
        params["prop_name"] => :name,
        :events => :total_conversions,
        :visitors => :unique_conversions
      })
      |> Enum.map(fn prop ->
        prop
        |> Map.put(:conversion_rate, calculate_cr(unique_visitors, prop[:unique_conversions]))
        |> Enum.map(&format_revenue_metric/1)
        |> Map.new()
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

    prop_names = Plausible.Stats.CustomProps.props_for_goal(site, query)

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

    query =
      Query.from(site, params)
      |> Filters.add_prefix()

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

  defp add_percentages([_ | _] = breakdown_result, site, query)
       when not is_map_key(query.filters, "event:goal") do
    %{visitors: %{value: total_visitors}} = Stats.aggregate(site, query, [:visitors])

    breakdown_result
    |> Enum.map(fn stat ->
      Map.put(stat, :percentage, Float.round(stat.visitors / total_visitors * 100, 1))
    end)
  end

  defp add_percentages(breakdown_result, _, _), do: breakdown_result

  defp add_cr([_ | _] = breakdown_results, site, query, pagination, key_name, filter_name)
       when is_map_key(query.filters, "event:goal") do
    items = Enum.map(breakdown_results, fn item -> Map.fetch!(item, key_name) end)

    query_without_goal =
      query
      |> Query.put_filter(filter_name, {:member, items})
      |> Query.remove_event_filters([:goal, :props])

    # Here, we're always only interested in the first page of results 
    # - the :member filter makes sure that the results always match with 
    # the items in the given breakdown_results list
    pagination = {elem(pagination, 0), 1}

    res_without_goal =
      Stats.breakdown(site, query_without_goal, filter_name, [:visitors], pagination)

    Enum.map(breakdown_results, fn item ->
      without_goal =
        Enum.find(res_without_goal, fn s ->
          Map.fetch!(s, key_name) == Map.fetch!(item, key_name)
        end)

      item
      |> Map.put(:total_visitors, without_goal.visitors)
      |> Map.put(:conversion_rate, calculate_cr(without_goal.visitors, item.visitors))
    end)
  end

  defp add_cr(breakdown_results, _, _, _, _, _), do: breakdown_results

  defp to_csv(list, columns), do: to_csv(list, columns, columns)

  defp to_csv(list, columns, column_names) do
    list
    |> Enum.map(fn row -> Enum.map(columns, &row[&1]) end)
    |> (fn res -> [column_names | res] end).()
    |> CSV.encode()
    |> Enum.join()
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

  defp validate_common_input(conn, _opts) do
    case validate_params(conn.assigns[:site], conn.params) do
      :ok -> conn
      {:error, message} when is_binary(message) -> bad_request(conn, message)
    end
  end

  defp validate_params(site, params) do
    with {:ok, dates} <- validate_dates(params),
         :ok <- validate_interval(params),
         do: validate_interval_granularity(site, params, dates)
  end

  defp validate_dates(params) do
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

  defp with_imported?(source_query, comparison_query) do
    cond do
      source_query.include_imported -> true
      comparison_query && comparison_query.include_imported -> true
      true -> false
    end
  end
end
