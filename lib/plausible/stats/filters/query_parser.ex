defmodule Plausible.Stats.Filters.QueryParser do
  alias Plausible.Stats.Filters

  def parse(params) when is_map(params) do
    with {:ok, metrics} <- parse_metrics(Map.get(params, "metrics", [])),
         {:ok, filters} <- parse_filters(Map.get(params, "filters", [])),
         {:ok, date_range} <- parse_date_range(Map.get(params, "date_range")),
         {:ok, dimensions} <- parse_dimensions(Map.get(params, "dimensions", [])),
         {:ok, order_by} <- parse_order_by(Map.get(params, "order_by")),
         query = %{
           metrics: metrics,
           filters: filters,
           date_range: date_range,
           dimensions: dimensions,
           order_by: order_by
         },
         :ok <- validate_order_by(query) do
      {:ok, query}
    end
  end

  defp parse_metrics([]), do: {:error, "No valid metrics passed"}

  defp parse_metrics(metrics) when is_list(metrics) do
    if length(metrics) == length(Enum.uniq(metrics)) do
      parse_list(metrics, &parse_metric/1)
    else
      {:error, "Metrics cannot be queried multiple times"}
    end
  end

  defp parse_metrics(_invalid_metrics), do: {:error, "Invalid metrics passed"}

  defp parse_metric("time_on_page"), do: {:ok, :time_on_page}
  defp parse_metric("conversion_rate"), do: {:ok, :conversion_rate}
  defp parse_metric("visitors"), do: {:ok, :visitors}
  defp parse_metric("pageviews"), do: {:ok, :pageviews}
  defp parse_metric("events"), do: {:ok, :events}
  defp parse_metric("visits"), do: {:ok, :visits}
  defp parse_metric("bounce_rate"), do: {:ok, :bounce_rate}
  defp parse_metric("visit_duration"), do: {:ok, :visit_duration}
  defp parse_metric(unknown_metric), do: {:error, "Unknown metric '#{inspect(unknown_metric)}'"}

  def parse_filters(filters) when is_list(filters) do
    parse_list(filters, &parse_filter/1)
  end

  def parse_filters(_invalid_metrics), do: {:error, "Invalid filters passed"}

  defp parse_filter(filter) do
    with {:ok, operator} <- parse_operator(filter),
         {:ok, filter_key} <- parse_filter_key(filter),
         {:ok, rest} <- parse_filter_rest(operator, filter) do
      {:ok, [operator, filter_key | rest]}
    end
  end

  defp parse_operator(["is" | _rest]), do: {:ok, :is}
  defp parse_operator(["is_not" | _rest]), do: {:ok, :is_not}
  defp parse_operator(["matches" | _rest]), do: {:ok, :matches}
  defp parse_operator(["does_not_match" | _rest]), do: {:ok, :does_not_match}
  defp parse_operator(filter), do: {:error, "Unknown operator for filter '#{inspect(filter)}'"}

  defp parse_filter_key([_operator, filter_key | _rest] = filter) do
    parse_filter_key_string(filter_key, "Invalid filter '#{inspect(filter)}")
  end

  defp parse_filter_key(filter), do: {:error, "Invalid filter '#{inspect(filter)}'"}

  defp parse_filter_rest(:is, filter), do: parse_clauses_list(filter)
  defp parse_filter_rest(:is_not, filter), do: parse_clauses_list(filter)
  defp parse_filter_rest(:matches, filter), do: parse_clauses_list(filter)
  defp parse_filter_rest(:does_not_match, filter), do: parse_clauses_list(filter)

  defp parse_filter_rest(_operator, filter), do: {:error, "Invalid filter '#{inspect(filter)}'"}

  defp parse_clauses_list([_, _, list] = filter) when is_list(list) do
    if Enum.all?(list, &is_bitstring/1) do
      {:ok, [list]}
    else
      {:error, "Invalid filter '#{inspect(filter)}'"}
    end
  end

  defp parse_clauses_list(filter), do: {:error, "Invalid filter '#{inspect(filter)}'"}

  defp parse_date_range("day"), do: {:ok, "day"}
  defp parse_date_range("7d"), do: {:ok, "7d"}
  defp parse_date_range("30d"), do: {:ok, "30d"}
  defp parse_date_range("month"), do: {:ok, "month"}
  defp parse_date_range("6mo"), do: {:ok, "6mo"}
  defp parse_date_range("12mo"), do: {:ok, "6mo"}
  defp parse_date_range("year"), do: {:ok, "year"}
  defp parse_date_range("all"), do: {:ok, "all"}

  defp parse_date_range([from_date_string, to_date_string])
       when is_bitstring(from_date_string) and is_bitstring(to_date_string) do
    with {:ok, from_date} <- Date.from_iso8601(from_date_string),
         {:ok, to_date} <- Date.from_iso8601(to_date_string) do
      {:ok, Date.range(from_date, to_date)}
    else
      _ -> {:error, "Invalid date_range '#{inspect([from_date_string, to_date_string])}'"}
    end
  end

  defp parse_date_range(unknown), do: {:error, "Invalid date range '#{inspect(unknown)}'"}

  defp parse_dimensions(dimensions) when is_list(dimensions) do
    if length(dimensions) == length(Enum.uniq(dimensions)) do
      parse_list(
        dimensions,
        &parse_filter_key_string(&1, "Invalid dimensions '#{inspect(dimensions)}'")
      )
    else
      {:error, "Some dimensions are listed multiple times"}
    end
  end

  defp parse_dimensions(dimensions), do: {:error, "Invalid dimensions '#{inspect(dimensions)}'"}

  def parse_order_by(order_by) when is_list(order_by) do
    parse_list(order_by, &parse_order_by_entry/1)
  end

  def parse_order_by(nil), do: {:ok, nil}
  def parse_order_by(order_by), do: {:error, "Invalid order_by '#{inspect(order_by)}'"}

  def parse_order_by_entry(entry) do
    with {:ok, metric_or_dimension} <- parse_metric_or_dimension(entry),
         {:ok, order_direction} <- parse_order_direction(entry) do
      {:ok, {metric_or_dimension, order_direction}}
    end
  end

  def parse_metric_or_dimension([metric_or_dimension, _] = entry) do
    case {parse_metric(metric_or_dimension), parse_filter_key_string(metric_or_dimension)} do
      {{:ok, metric}, _} -> {:ok, metric}
      {_, {:ok, dimension}} -> {:ok, dimension}
      _ -> {:error, "Invalid order_by entry '#{inspect(entry)}'"}
    end
  end

  def parse_order_direction([_, "asc"]), do: {:ok, :asc}
  def parse_order_direction([_, "desc"]), do: {:ok, :desc}
  def parse_order_direction(entry), do: {:error, "Invalid order_by entry '#{inspect(entry)}'"}

  defp parse_filter_key_string(filter_key, error_message \\ "") do
    case filter_key do
      "event:props:" <> _property_name ->
        {:ok, filter_key}

      "event:" <> key ->
        if key in Filters.event_props() do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

      "visit:" <> key ->
        if key in Filters.visit_props() do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

      _ ->
        {:error, error_message}
    end
  end

  def validate_order_by(query) do
    if query.order_by do
      valid_values = query.metrics ++ query.dimensions

      invalid_entry =
        Enum.find(query.order_by, fn {value, _direction} ->
          not Enum.member?(valid_values, value)
        end)

      case invalid_entry do
        nil ->
          :ok

        _ ->
          {:error,
           "Invalid order_by entry '#{inspect(invalid_entry)}'. Entry is not a queried metric or dimension"}
      end
    else
      :ok
    end
  end

  defp parse_list(list, parser_function) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, results} ->
      case parser_function.(value) do
        {:ok, result} -> {:cont, {:ok, results ++ [result]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
