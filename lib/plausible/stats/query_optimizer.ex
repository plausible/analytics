defmodule Plausible.Stats.QueryOptimizer do
  @moduledoc """
  Methods to manipulate Query for business logic reasons before building an ecto query.
  """

  use Plausible

  alias Plausible.Stats.{
    DateTimeRange,
    Filters,
    Query,
    TableDecider,
    TimeOnPage,
    Util,
    Time,
    Legacy
  }

  @doc """
    This module manipulates an existing query, updating it according to business logic.

    For example, it:
    1. Figures out what the right granularity to group by time is
    2. Adds a missing order_by clause to a query
    3. Updating "time" dimension in order_by to the right granularity
    4. Updates event:hostname filters to also apply on visit level for sane results.
    5. Removes revenue metrics from dashboard queries if not requested, present or unavailable for the site.

  """
  def optimize(query) do
    Enum.reduce(pipeline(), query, fn step, acc -> step.(acc) end)
  end

  @doc """
  Splits a query into event and sessions subcomponents as not all metrics can be
  queried from a single table.

  event:page dimension is treated in a special way, doing a breakdown of visit:entry_page
  for sessions.
  """
  def split(query) do
    {event_metrics, sessions_metrics, _other_metrics} =
      query.metrics
      |> Util.maybe_add_visitors_metric()
      |> TableDecider.partition_metrics(query)

    {
      Query.set(query,
        metrics: event_metrics,
        include_imported: query.include_imported
      ),
      split_sessions_query(query, sessions_metrics)
    }
  end

  defp pipeline() do
    [
      &trim_relative_date_range/1,
      &update_group_by_time/1,
      &add_missing_order_by/1,
      &update_time_in_order_by/1,
      &extend_hostname_filters_to_visit/1,
      &remove_revenue_metrics_if_unavailable/1,
      &set_time_on_page_data/1
    ]
  end

  defp add_missing_order_by(%Query{order_by: nil} = query) do
    order_by =
      case time_dimension(query) do
        nil -> [{hd(query.metrics), :desc}]
        time_dimension -> [{time_dimension, :asc}, {hd(query.metrics), :desc}]
      end

    %Query{query | order_by: order_by}
  end

  defp add_missing_order_by(query), do: query

  defp update_group_by_time(
         %Query{
           utc_time_range: %DateTimeRange{first: first, last: last}
         } = query
       ) do
    dimensions =
      query.dimensions
      |> Enum.map(fn
        "time" -> resolve_time_dimension(first, last)
        entry -> entry
      end)

    %Query{query | dimensions: dimensions}
  end

  defp update_group_by_time(query), do: query

  defp resolve_time_dimension(first, last) do
    cond do
      DateTime.diff(last, first, :hour) <= 48 -> "time:hour"
      DateTime.diff(last, first, :day) <= 40 -> "time:day"
      Timex.diff(last, first, :weeks) <= 52 -> "time:week"
      true -> "time:month"
    end
  end

  defp update_time_in_order_by(query) do
    order_by =
      query.order_by
      |> Enum.map(fn
        {"time", direction} -> {time_dimension(query), direction}
        entry -> entry
      end)

    %Query{query | order_by: order_by}
  end

  @dimensions_hostname_map %{
    "visit:source" => "visit:entry_page_hostname",
    "visit:entry_page" => "visit:entry_page_hostname",
    "visit:utm_medium" => "visit:entry_page_hostname",
    "visit:utm_source" => "visit:entry_page_hostname",
    "visit:utm_campaign" => "visit:entry_page_hostname",
    "visit:utm_content" => "visit:entry_page_hostname",
    "visit:utm_term" => "visit:entry_page_hostname",
    "visit:referrer" => "visit:entry_page_hostname",
    "visit:exit_page" => "visit:exit_page_hostname"
  }

  # To avoid showing referrers across hostnames when event:hostname
  # filter is present for breakdowns, add entry/exit page hostname
  # filters
  defp extend_hostname_filters_to_visit(query) do
    # Note: Only works since event:hostname is only allowed as a top level filter
    hostname_filters =
      query.filters
      |> Enum.filter(fn [_operation, dimension | _rest] -> dimension == "event:hostname" end)

    if length(hostname_filters) > 0 do
      extra_filters =
        query.dimensions
        |> Enum.flat_map(&hostname_filters_for_dimension(&1, hostname_filters))

      %Query{query | filters: query.filters ++ extra_filters}
    else
      query
    end
  end

  defp hostname_filters_for_dimension(dimension, hostname_filters) do
    if Map.has_key?(@dimensions_hostname_map, dimension) do
      dimension = Map.get(@dimensions_hostname_map, dimension)

      hostname_filters
      |> Enum.map(fn [operation, _dimension | rest] -> [operation, dimension | rest] end)
    else
      []
    end
  end

  defp time_dimension(query) do
    Enum.find(query.dimensions, &Time.time_dimension?/1)
  end

  defp split_sessions_query(query, session_metrics) do
    dimensions =
      query.dimensions
      |> Enum.map(fn
        "event:page" -> "visit:entry_page"
        dimension -> dimension
      end)

    filters =
      if "event:page" in query.dimensions do
        Filters.rename_dimensions_used_in_filter(query.filters, %{
          "event:page" => "visit:entry_page"
        })
      else
        query.filters
      end

    Query.set(query,
      filters: filters,
      metrics: session_metrics,
      dimensions: dimensions,
      include_imported: query.include_imported
    )
  end

  on_ee do
    defp remove_revenue_metrics_if_unavailable(query) do
      if query.remove_unavailable_revenue_metrics and map_size(query.revenue_currencies) == 0 do
        Query.set(query, metrics: query.metrics -- Plausible.Stats.Goal.Revenue.revenue_metrics())
      else
        query
      end
    end
  else
    defp remove_revenue_metrics_if_unavailable(query), do: query
  end

  defp set_time_on_page_data(query) do
    case {:time_on_page in query.metrics, query.time_on_page_data} do
      {true, %{new_metric_visible: true, cutoff_date: cutoff_date}} ->
        cutoff =
          cutoff_date
          |> TimeOnPage.cutoff_datetime(query.timezone)
          |> DateTime.shift_zone!("Etc/UTC")
          |> DateTime.truncate(:second)

        Query.set(
          query,
          time_on_page_data:
            Map.merge(query.time_on_page_data, %{
              include_new_metric: DateTime.before?(cutoff, query.utc_time_range.last),
              include_legacy_metric:
                DateTime.after?(cutoff, query.utc_time_range.first) and
                  Legacy.TimeOnPage.can_merge_legacy_time_on_page?(query),
              cutoff:
                if(DateTime.after?(cutoff, query.utc_time_range.first), do: cutoff, else: nil)
            })
        )

      _ ->
        Query.set(
          query,
          time_on_page_data:
            Map.merge(query.time_on_page_data, %{
              include_new_metric: false,
              include_legacy_metric: true,
              cutoff: nil
            })
        )
    end
  end

  defp trim_relative_date_range(%Query{include: %{trim_relative_date_range: true}} = query) do
    # This is here to trim future bucket labels on the main graph
    if should_trim_current_period?(query) do
      trimmed_range = trim_date_range_to_now(query)
      %Query{query | utc_time_range: trimmed_range}
    else
      query
    end
  end

  defp trim_relative_date_range(query), do: query

  defp should_trim_current_period?(%Query{period: "month"} = query) do
    today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()
    date_range = Query.date_range(query)

    current_month_start = Date.beginning_of_month(today)
    current_month_end = Date.end_of_month(today)

    date_range.first == current_month_start and date_range.last == current_month_end
  end

  defp should_trim_current_period?(%Query{period: "year"} = query) do
    today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()
    date_range = Query.date_range(query)

    current_year_start = Date.new!(today.year, 1, 1)
    current_year_end = Date.new!(today.year, 12, 31)

    date_range.first == current_year_start and date_range.last == current_year_end
  end

  defp should_trim_current_period?(%Query{period: "day"} = query) do
    today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()
    date_range = Query.date_range(query)

    date_range.first == today and date_range.last == today
  end

  defp should_trim_current_period?(_query), do: false

  defp trim_date_range_to_now(query) do
    if query.period == "day" do
      time_range = query.utc_time_range |> DateTimeRange.to_timezone(query.timezone)

      current_hour =
        query.now
        |> DateTime.shift_zone!(query.timezone)
        |> Map.merge(%{minute: 0, second: 0})

      time_range.first
      |> DateTimeRange.new!(current_hour)
      |> DateTimeRange.to_timezone("Etc/UTC")
    else
      date_range = Query.date_range(query)
      today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()

      trimmed_to_date =
        Enum.min([date_range.last, today], Date)

      date_range.first
      |> DateTimeRange.new!(trimmed_to_date, query.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")
    end
  end
end
