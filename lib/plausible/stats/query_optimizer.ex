defmodule Plausible.Stats.QueryOptimizer do
  @moduledoc """
  Methods to manipulate Query for business logic reasons before building an ecto query.
  """

  use Plausible
  alias Plausible.Stats.{Query, TableDecider, Util}

  @doc """
    This module manipulates an existing query, updating it according to business logic.

    For example, it:
    1. Figures out what the right granularity to group by time is
    2. Adds a missing order_by clause to a query
    3. Updating "time" dimension in order_by to the right granularity

  """
  def optimize(query, site) do
    Enum.reduce(pipeline(), query, fn step, acc -> step.(site, acc) end)
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
      Query.set_metrics(query, event_metrics),
      split_sessions_query(query, sessions_metrics)
    }
  end

  defp pipeline() do
    [
      &update_group_by_time/2,
      &add_missing_order_by/2,
      &update_time_in_order_by/2,
      &extend_hostname_filters_to_visit/2,
      &update_revenue_metrics/2
    ]
  end

  defp add_missing_order_by(_site, %Query{order_by: nil} = query) do
    order_by =
      case time_dimension(query) do
        nil -> [{hd(query.metrics), :desc}]
        time_dimension -> [{time_dimension, :asc}, {hd(query.metrics), :desc}]
      end

    %Query{query | order_by: order_by}
  end

  defp add_missing_order_by(_site, query), do: query

  defp update_group_by_time(
         _site,
         %Query{
           date_range: %Date.Range{first: first, last: last}
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

  defp update_group_by_time(_site, query), do: query

  defp resolve_time_dimension(first, last) do
    cond do
      Timex.diff(last, first, :hours) <= 48 -> "time:hour"
      Timex.diff(last, first, :days) <= 40 -> "time:day"
      true -> "time:month"
    end
  end

  defp update_time_in_order_by(_site, query) do
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
  defp extend_hostname_filters_to_visit(_site, query) do
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
    Enum.find(query.dimensions, &String.starts_with?(&1, "time"))
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
        query.filters
        |> Enum.map(fn
          [op, "event:page" | rest] -> [op, "visit:entry_page" | rest]
          filter -> filter
        end)
      else
        query.filters
      end

    Query.set(query, filters: filters, metrics: session_metrics, dimensions: dimensions)
  end

  defp update_revenue_metrics(site, query) do
    {currency, metrics} =
      on_ee do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, query.metrics)
      else
        {nil, metrics}
      end

    %Query{query | currency: currency, metrics: metrics}
  end
end
