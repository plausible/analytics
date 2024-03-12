defmodule Plausible.Stats.TableDecider do
  import Enum, only: [empty?: 1]

  alias Plausible.Stats.Query

  def partition_metrics(metrics, query) do
    %{event: event_metrics, session: session_metrics, both: both_metrics, other: other_metrics} =
      partition(metrics, query, &metric_partitioner/2)

    %{event: event_filters, session: session_filters, both: _both_filters} =
      partition(query.filters, query, &filters_partitioner/2)

    cond do
      # Only one table needs to be queried
      empty?(session_metrics) && empty?(session_filters) ->
        {event_metrics ++ both_metrics, [], other_metrics}

      empty?(event_metrics) && empty?(event_filters) ->
        {[], session_metrics ++ both_metrics, other_metrics}

      # Filters from both, but only one kind of metric
      empty?(session_metrics) ->
        {event_metrics ++ both_metrics, [], other_metrics}

      # Default: prefer sessions
      true ->
        {event_metrics, session_metrics ++ both_metrics, other_metrics}
    end
  end

  defp metric_partitioner(_, :conversion_rate), do: :event
  defp metric_partitioner(_, :average_revenue), do: :event
  defp metric_partitioner(_, :total_revenue), do: :event
  defp metric_partitioner(_, :bounce_rate), do: :session
  defp metric_partitioner(_, :visit_duration), do: :session
  defp metric_partitioner(_, :views_per_visit), do: :session
  # :TODO: These can be calculated on the other table as well!
  defp metric_partitioner(_, :visits), do: :session
  defp metric_partitioner(_, :pageviews), do: :event
  defp metric_partitioner(_, :events), do: :event
  defp metric_partitioner(_, :visitors), do: :event
  # :TODO: Calculated/weird metrics
  defp metric_partitioner(_, :time_on_page), do: :other
  defp metric_partitioner(_, :total_visitors), do: :other
  # :TODO: Should be included on _both_
  defp metric_partitioner(_, :sample_percent), do: :event

  defp metric_partitioner(%Query{experimental_reduced_joins?: false}, unknown) do
    raise ArgumentError, "Metric #{unknown} not supported without experimental_reduced_joins?"
  end

  defp metric_partitioner(_, _), do: :both

  defp filters_partitioner(_, {"event:name", _}), do: :event
  defp filters_partitioner(_, {"event:page", _}), do: :event
  defp filters_partitioner(_, {"event:goal", _}), do: :event
  defp filters_partitioner(_, {"event:props:" <> _prop, _}), do: :event
  defp filters_partitioner(_, {"visit:entry_page", _}), do: :session
  defp filters_partitioner(_, {"visit:exit_page", _}), do: :session

  defp filters_partitioner(%Query{experimental_reduced_joins?: false}, {"visit:" <> _, _}),
    do: :session

  defp filters_partitioner(%Query{experimental_reduced_joins?: false}, {unknown, _}) do
    raise ArgumentError, "Filter #{unknown} not supported without experimental_reduced_joins?"
  end

  defp filters_partitioner(_, _), do: :both

  @default %{event: [], session: [], both: [], other: []}
  defp partition(values, query, partitioner) do
    Enum.reduce(values, @default, fn value, acc ->
      key = partitioner.(query, value)
      Map.put(acc, key, Map.fetch!(acc, key) ++ [value])
    end)
  end
end
