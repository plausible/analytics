defmodule Plausible.Stats.TableDecider do
  @moduledoc """
  This module contains logic for deciding which tables need to be queried given a query
  and metrics, with the purpose of reducing the number of queries and JOINs needed to perform.
  """

  import Enum, only: [empty?: 1]
  import Plausible.Stats.Filters, only: [dimensions_used_in_filters: 1]

  alias Plausible.Stats.Query

  def events_join_sessions?(query) do
    query.filters
    |> dimensions_used_in_filters()
    |> Enum.any?(&(dimension_partitioner(query, &1) == :session))
  end

  def sessions_join_events?(query) do
    query.filters
    |> dimensions_used_in_filters()
    |> Enum.any?(&(dimension_partitioner(query, &1) == :event))
  end

  @doc """
  Validates whether metrics and dimensions are compatible with each other.

  During query building we split query into two: event and session queries. However dimensions need to be
  present in both queries and hence must be compatible.

  Used during query parsing
  """
  def validate_no_metrics_dimensions_conflict(query) do
    %{event: event_only_metrics, session: session_only_metrics} =
      partition(query.metrics, query, &metric_partitioner/2)

    %{event: event_only_dimensions, session: session_only_dimensions} =
      partition(query.dimensions, query, &dimension_partitioner/2)

    cond do
      # event:page is a special case handled in QueryOptimizer.split_sessions_query
      event_only_dimensions == ["event:page"] ->
        :ok

      not empty?(session_only_metrics) and not empty?(event_only_dimensions) ->
        {:error,
         "Session metric(s) #{i(session_only_metrics)} cannot be queried along with event dimension(s) #{i(event_only_dimensions)}"}

      not empty?(event_only_metrics) and not empty?(session_only_dimensions) ->
        {:error,
         "Event metric(s) #{i(event_only_metrics)} cannot be queried along with session dimension(s) #{i(session_only_dimensions)}"}

      true ->
        :ok
    end
  end

  @doc """
  Returns a three-element tuple with instructions on how to join two Ecto
  queries. The arguments (`events_query` and `sessions_query`) are `%Query{}`
  structs that have been split by TableDecider already.

  Normally we can always LEFT JOIN sessions to events, selecting `dimensions`
  only from the events subquery. That's because:

  1) session dimensions (e.g. entry_page) cannot be queried alongside event
     metrics/dimensions, or

  2) session dimensions (e.g. operating_system) are also available in the
     events table.

  The only exception is using the "time:minute" dimension where the sessions
  subquery might return more rows than the events one. That's because we're
  counting sessions in all time buckets they were active in.
  """
  def join_options(events_query, sessions_query) do
    events_q_select_fields = events_query.metrics ++ events_query.dimensions
    sessions_q_select_fields = sessions_query.metrics -- [:sample_percent]

    if "time:minute" in events_query.dimensions do
      {
        :full,
        events_q_select_fields -- ["time:minute"],
        sessions_q_select_fields ++ ["time:minute"]
      }
    else
      {:left, events_q_select_fields, sessions_q_select_fields}
    end
  end

  @type table_type() :: :events | :sessions
  @type metric() :: String.t()

  @spec partition_metrics(list(metric()), Query.t()) :: list({table_type(), list(metric())})
  def partition_metrics(requested_metrics, query) do
    metrics = partition(requested_metrics, query, &metric_partitioner/2)

    filters =
      query.filters
      |> dimensions_used_in_filters()
      |> partition(query, &dimension_partitioner/2)

    dimensions = partition(query.dimensions, query, &dimension_partitioner/2)

    cond do
      # Only one table needs to be queried
      empty?(metrics.event) && empty?(filters.event) && empty?(dimensions.event) ->
        [sessions: metrics.session ++ metrics.either ++ metrics.sample_percent]

      empty?(metrics.session) && empty?(filters.session) && empty?(dimensions.session) ->
        [events: metrics.event ++ metrics.either ++ metrics.sample_percent]

      # Filters and/or dimensions on both events and sessions, but only one kind of metric
      empty?(metrics.event) && empty?(dimensions.event) ->
        [sessions: metrics.session ++ metrics.either ++ metrics.sample_percent]

      empty?(metrics.session) && empty?(dimensions.session) ->
        [events: metrics.event ++ metrics.either ++ metrics.sample_percent]

      # Default: prefer events
      true ->
        [
          events: metrics.event ++ metrics.either ++ metrics.sample_percent,
          sessions: metrics.session ++ metrics.sample_percent
        ]
    end
    |> Enum.reject(fn {_table_type, metrics} -> empty?(metrics) end)
  end

  # Note: This is inaccurate when filtering but required for old backwards compatibility
  defp metric_partitioner(%Query{legacy_breakdown: true}, :pageviews), do: :either
  defp metric_partitioner(%Query{legacy_breakdown: true}, :events), do: :either

  defp metric_partitioner(query, metric) when metric in [:visitors, :visits] do
    if "time:minute" in query.dimensions, do: :session, else: :either
  end

  defp metric_partitioner(_, :conversion_rate), do: :either
  defp metric_partitioner(_, :group_conversion_rate), do: :either
  defp metric_partitioner(_, :percentage), do: :either

  defp metric_partitioner(_, :average_revenue), do: :event
  defp metric_partitioner(_, :total_revenue), do: :event
  defp metric_partitioner(_, :scroll_depth), do: :event
  defp metric_partitioner(_, :pageviews), do: :event
  defp metric_partitioner(_, :events), do: :event
  defp metric_partitioner(_, :bounce_rate), do: :session
  defp metric_partitioner(_, :time_on_page), do: :event
  defp metric_partitioner(_, :visit_duration), do: :session
  defp metric_partitioner(_, :views_per_visit), do: :session
  defp metric_partitioner(_, :exit_rate), do: :session

  # Calculated metrics - handled on callsite separately from other metrics.
  defp metric_partitioner(_, :total_visitors), do: :other
  # Sample percentage is included in both tables if queried.
  defp metric_partitioner(_, :sample_percent), do: :sample_percent

  defp dimension_partitioner(_, "event:" <> _), do: :event
  defp dimension_partitioner(_, "visit:entry_page"), do: :session
  defp dimension_partitioner(_, "visit:entry_page_hostname"), do: :session
  defp dimension_partitioner(_, "visit:exit_page"), do: :session
  defp dimension_partitioner(_, "visit:exit_page_hostname"), do: :session

  defp dimension_partitioner(_, "visit:" <> _), do: :either

  defp dimension_partitioner(_, _), do: :either

  @default %{event: [], session: [], either: [], other: [], sample_percent: []}
  defp partition(values, query, partitioner) do
    Enum.reduce(values, @default, fn value, acc ->
      key = partitioner.(query, value)
      Map.put(acc, key, Map.fetch!(acc, key) ++ [value])
    end)
  end

  defp i(list) when is_list(list) do
    Enum.map_join(list, ", ", &"`#{&1}`")
  end
end
