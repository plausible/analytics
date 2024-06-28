defmodule Plausible.Stats.TableDecider do
  @moduledoc """
  This module contains logic for deciding which tables need to be queried given a query
  and metrics, with the purpose of reducing the number of queries and JOINs needed to perform.
  """

  import Enum, only: [empty?: 1]

  alias Plausible.Stats.Query

  def events_join_sessions?(query) do
    query
    |> filter_keys()
    |> Enum.any?(&(filters_partitioner(query, &1) == :session))
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
      query
      |> filter_keys()
      |> partition(query, &filters_partitioner/2)

    cond do
      # Only one table needs to be queried
      empty?(event_only_metrics) && empty?(event_only_filters) ->
        {[], session_only_metrics ++ either_metrics ++ sample_percent, other_metrics}

      empty?(session_only_metrics) && empty?(session_only_filters) ->
        {event_only_metrics ++ either_metrics ++ sample_percent, [], other_metrics}

      # Filters on both events and sessions, but only one kind of metric
      empty?(event_only_metrics) ->
        {[], session_only_metrics ++ either_metrics ++ sample_percent, other_metrics}

      empty?(session_only_metrics) ->
        {event_only_metrics ++ either_metrics ++ sample_percent, [], other_metrics}

      # Default: prefer sessions
      true ->
        {event_only_metrics ++ sample_percent,
         session_only_metrics ++ either_metrics ++ sample_percent, other_metrics}
    end
  end

  defp filter_keys(query) do
    query.filters
    |> Enum.map(fn [_, filter_key | _rest] -> filter_key end)
    |> Enum.concat(query.dimensions)
  end

  defp metric_partitioner(_, :conversion_rate), do: :event
  defp metric_partitioner(_, :group_conversion_rate), do: :event
  defp metric_partitioner(_, :average_revenue), do: :event
  defp metric_partitioner(_, :total_revenue), do: :event
  defp metric_partitioner(_, :pageviews), do: :event
  defp metric_partitioner(_, :events), do: :event
  defp metric_partitioner(_, :bounce_rate), do: :session
  defp metric_partitioner(_, :visit_duration), do: :session
  defp metric_partitioner(_, :views_per_visit), do: :session

  # Metrics which used to only be queried from one table but can be calculated from either
  defp metric_partitioner(%Query{experimental_reduced_joins?: true}, :visits), do: :either
  defp metric_partitioner(%Query{experimental_reduced_joins?: true}, :visitors), do: :either

  defp metric_partitioner(_, :visits), do: :session
  defp metric_partitioner(_, :visitors), do: :event
  # Calculated metrics - handled on callsite separately from other metrics.
  defp metric_partitioner(_, :time_on_page), do: :other
  defp metric_partitioner(_, :total_visitors), do: :other
  defp metric_partitioner(_, :percentage), do: :other
  # Sample percentage is included in both tables if queried.
  defp metric_partitioner(_, :sample_percent), do: :sample_percent

  defp metric_partitioner(%Query{experimental_reduced_joins?: false}, unknown) do
    raise ArgumentError, "Metric #{unknown} not supported without experimental_reduced_joins?"
  end

  defp metric_partitioner(_, _), do: :either

  defp filters_partitioner(_, "event:" <> _), do: :event
  defp filters_partitioner(_, "visit:entry_page"), do: :session
  defp filters_partitioner(_, "visit:entry_page_hostname"), do: :session
  defp filters_partitioner(_, "visit:exit_page"), do: :session
  defp filters_partitioner(_, "visit:exit_page_hostname"), do: :session

  defp filters_partitioner(%Query{experimental_reduced_joins?: true}, "visit:" <> _),
    do: :either

  defp filters_partitioner(_, "visit:" <> _),
    do: :session

  defp filters_partitioner(%Query{experimental_reduced_joins?: false}, {unknown, _}) do
    raise ArgumentError, "Filter #{unknown} not supported without experimental_reduced_joins?"
  end

  defp filters_partitioner(_, _), do: :either

  @default %{event: [], session: [], either: [], other: [], sample_percent: []}
  defp partition(values, query, partitioner) do
    Enum.reduce(values, @default, fn value, acc ->
      key = partitioner.(query, value)
      Map.put(acc, key, Map.fetch!(acc, key) ++ [value])
    end)
  end
end
