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

  def partition_metrics(metrics, query) do
    %{
      event: event_only_metrics,
      session: session_only_metrics,
      either: either_metrics,
      other: other_metrics,
      sample_percent: sample_percent
    } =
      partition(metrics, query, &metric_partitioner/2)

    %{event: event_only_filters, session: session_only_filters} =
      query.filters
      |> dimensions_used_in_filters()
      |> partition(query, &dimension_partitioner/2)

    %{event: event_only_dimensions, session: session_only_dimensions} =
      partition(query.dimensions, query, &dimension_partitioner/2)

    cond do
      # Only one table needs to be queried
      empty?(event_only_metrics) && empty?(event_only_filters) && empty?(event_only_dimensions) ->
        {[], session_only_metrics ++ either_metrics ++ sample_percent, other_metrics}

      empty?(session_only_metrics) && empty?(session_only_filters) &&
          empty?(session_only_dimensions) ->
        {event_only_metrics ++ either_metrics ++ sample_percent, [], other_metrics}

      # Filters and/or dimensions on both events and sessions, but only one kind of metric
      empty?(event_only_metrics) && empty?(event_only_dimensions) ->
        {[], session_only_metrics ++ either_metrics ++ sample_percent, other_metrics}

      empty?(session_only_metrics) && empty?(session_only_dimensions) ->
        {event_only_metrics ++ either_metrics ++ sample_percent, [], other_metrics}

      # Default: prefer events
      true ->
        {event_only_metrics ++ either_metrics ++ sample_percent,
         session_only_metrics ++ sample_percent, other_metrics}
    end
  end

  # Note: This is inaccurate when filtering but required for old backwards compatibility
  defp metric_partitioner(%Query{legacy_breakdown: true}, :pageviews), do: :either
  defp metric_partitioner(%Query{legacy_breakdown: true}, :events), do: :either

  defp metric_partitioner(_, :conversion_rate), do: :either
  defp metric_partitioner(_, :group_conversion_rate), do: :either
  defp metric_partitioner(_, :visitors), do: :either
  defp metric_partitioner(_, :visits), do: :either
  defp metric_partitioner(_, :percentage), do: :either

  defp metric_partitioner(_, :average_revenue), do: :event
  defp metric_partitioner(_, :total_revenue), do: :event
  defp metric_partitioner(_, :scroll_depth), do: :event
  defp metric_partitioner(_, :pageviews), do: :event
  defp metric_partitioner(_, :events), do: :event
  defp metric_partitioner(_, :bounce_rate), do: :session
  defp metric_partitioner(_, :visit_duration), do: :session
  defp metric_partitioner(_, :views_per_visit), do: :session

  # Calculated metrics - handled on callsite separately from other metrics.
  defp metric_partitioner(_, :time_on_page), do: :other
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
end
