defmodule Plausible.Stats.Query.ApiParser do
  @moduledoc false

  use Plausible

  alias Plausible.Stats.{Filters, Metrics, JSONSchema, QueryError, QueryPeriod}

  @default_include %Plausible.Stats.Query.Include{
    imports: false,
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    trim_relative_date_range: false,
    compare: nil,
    compare_match_day_of_week: false,
    legacy_time_on_page_cutoff: nil
  }

  def default_include(), do: @default_include

  @default_pagination %{limit: 10_000, offset: 0}

  def default_pagination(), do: @default_pagination

  def parse(params, opts \\ []) when is_map(params) do
    with :ok <- JSONSchema.validate(params),
         {:ok, input_date_range} <- QueryPeriod.parse_input_date_range(params["date_range"]),
         {:ok, metrics} <- parse_metrics(Map.fetch!(params, "metrics")),
         {:ok, filters} <- Filters.Parser.parse(params["filters"]),
         {:ok, dimensions} <- parse_dimensions(params["dimensions"]),
         {:ok, order_by} <- parse_order_by(params["order_by"]),
         {:ok, pagination} <- parse_pagination(params["pagination"]),
         {:ok, include} <- parse_include(params["include"]) do
      {:ok,
       Plausible.Stats.Query.ParsedParams.new!(%{
         input_date_range: input_date_range,
         metrics: metrics,
         filters: filters,
         dimensions: dimensions,
         order_by: order_by,
         pagination: pagination,
         include: include,
         now: Keyword.get(opts, :now)
       })}
    end
  end

  def parse_metrics(metrics) when is_list(metrics) do
    parse_list(metrics, &parse_metric/1)
  end

  defp parse_metric(metric_str) do
    case Metrics.from_string(metric_str) do
      {:ok, metric} ->
        {:ok, metric}

      _ ->
        {:error,
         %QueryError{code: :invalid_metrics, message: "Unknown metric '#{i(metric_str)}'."}}
    end
  end

  def parse_dimensions(dimensions) when is_list(dimensions) do
    parse_list(
      dimensions,
      &parse_dimension_entry(&1, "Invalid dimensions '#{i(dimensions)}'")
    )
  end

  def parse_dimensions(nil), do: {:ok, []}

  def parse_order_by(order_by) when is_list(order_by) do
    parse_list(order_by, &parse_order_by_entry/1)
  end

  def parse_order_by(nil), do: {:ok, nil}

  def parse_order_by(order_by),
    do:
      {:error,
       %QueryError{code: :invalid_order_by, message: "Invalid order_by '#{i(order_by)}'."}}

  defp parse_order_by_entry(entry) do
    with {:ok, value} <- parse_metric_or_dimension(entry),
         {:ok, order_direction} <- parse_order_direction(entry) do
      {:ok, {value, order_direction}}
    end
  end

  defp parse_dimension_entry(key, error_message) do
    case {
      parse_time_dimension(key),
      parse_non_time_dimension(key)
    } do
      {{:ok, time}, _} -> {:ok, time}
      {_, {:ok, dimension}} -> {:ok, dimension}
      _ -> {:error, %QueryError{code: :invalid_dimensions, message: error_message}}
    end
  end

  defp parse_metric_or_dimension([value, _] = entry) do
    case {
      parse_time_dimension(value),
      parse_metric(value),
      parse_non_time_dimension(value)
    } do
      {{:ok, time_dimension}, _, _} ->
        {:ok, time_dimension}

      {_, {:ok, metric}, _} ->
        {:ok, metric}

      {_, _, {:ok, non_time_dimension}} ->
        {:ok, non_time_dimension}

      _ ->
        {:error,
         %QueryError{code: :invalid_order_by, message: "Invalid order_by entry '#{i(entry)}'."}}
    end
  end

  defp parse_time_dimension("time"), do: {:ok, "time"}
  defp parse_time_dimension("time:minute"), do: {:ok, "time:minute"}
  defp parse_time_dimension("time:hour"), do: {:ok, "time:hour"}
  defp parse_time_dimension("time:day"), do: {:ok, "time:day"}
  defp parse_time_dimension("time:week"), do: {:ok, "time:week"}
  defp parse_time_dimension("time:month"), do: {:ok, "time:month"}
  defp parse_time_dimension(_), do: :error

  @breakdown_only_non_time_dimensions ["event:prop_key"]

  defp parse_non_time_dimension(dimension) do
    if dimension in @breakdown_only_non_time_dimensions do
      {:ok, dimension}
    else
      Filters.Parser.parse_filter_dimension(dimension)
    end
  end

  defp parse_order_direction([_, "asc"]), do: {:ok, :asc}
  defp parse_order_direction([_, "desc"]), do: {:ok, :desc}

  defp parse_order_direction(entry),
    do:
      {:error,
       %QueryError{code: :invalid_order_by, message: "Invalid order_by entry '#{i(entry)}'."}}

  def parse_include(include) when is_map(include) do
    parsed_include_params_or_error =
      include
      |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, acc} ->
        case parse_include_entry(key, value) do
          {:ok, parsed_tuple} -> {:cont, {:ok, acc ++ [parsed_tuple]}}
          {:error, query_error} -> {:halt, {:error, query_error}}
        end
      end)

    with {:ok, parsed_include_params} <- parsed_include_params_or_error do
      {:ok, struct!(@default_include, parsed_include_params)}
    end
  end

  def parse_include(nil), do: {:ok, @default_include}

  def parse_include(include),
    do: {:error, %QueryError{code: :invalid_include, message: "Invalid include '#{i(include)}'."}}

  @allowed_include_keys Enum.map(Map.keys(@default_include), &Atom.to_string/1)

  defp parse_include_entry(key, value) when key in @allowed_include_keys do
    {:ok, {String.to_existing_atom(key), value}}
  end

  defp parse_include_entry(key, _value),
    do: {:error, %QueryError{code: :invalid_include, message: "Invalid include key'#{i(key)}'."}}

  def parse_pagination(pagination) when is_map(pagination) do
    {:ok, Map.merge(@default_pagination, atomize_keys(pagination))}
  end

  def parse_pagination(nil), do: {:ok, @default_pagination}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {String.to_existing_atom(key), value}
    end)
  end

  defp i(value), do: inspect(value, charlists: :as_lists)

  defp parse_list(list, parser_function) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, results} ->
      case parser_function.(value) do
        {:ok, result} -> {:cont, {:ok, results ++ [result]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
