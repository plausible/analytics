defmodule Plausible.Stats.QueryOptimizer do
  @moduledoc """
  Methods to manipulate Query for business logic reasons before building an ecto query.
  """

  use Plausible
  alias Plausible.Stats.{DateTimeRange, Filters, Query, TableDecider, Util, Time}

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
      &update_group_by_time/1,
      &add_missing_order_by/1,
      &update_time_in_order_by/1,
      &extend_hostname_filters_to_visit/1,
      &remove_revenue_metrics_if_unavailable/1
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
      |> Enum.filter(fn [_operation, filter_key | _rest] -> filter_key == "event:hostname" end)

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
      filter_key = Map.get(@dimensions_hostname_map, dimension)

      hostname_filters
      |> Enum.map(fn [operation, _filter_key | rest] -> [operation, filter_key | rest] end)
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
      if query.include[:remove_unavailable_revenue_metrics] and map_size(query.revenue_currencies) == 0 do
        Query.set(query, metrics: query.metrics -- Plausible.Stats.Goal.Revenue.revenue_metrics())
      else
        query
      end
    end
  else
    defp remove_revenue_metrics_if_unavailable(query), do: query
  end
end
