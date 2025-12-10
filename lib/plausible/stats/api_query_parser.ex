defmodule Plausible.Stats.ApiQueryParser do
  @moduledoc false

  use Plausible

  alias Plausible.Stats.{Filters, Metrics, DateTimeRange, JSONSchema}

  @default_include %{
    imports: false,
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    trim_relative_date_range: false,
    comparisons: nil,
    legacy_time_on_page_cutoff: nil
  }

  def default_include(), do: @default_include

  @default_pagination %{limit: 10_000, offset: 0}

  def default_pagination(), do: @default_pagination

  def parse(schema_type, params) when is_map(params) do
    input_date_range = Map.get(params, "date_range")

    with :ok <- JSONSchema.validate(schema_type, params),
         {:ok, input_date_range} <- parse_input_date_range(input_date_range),
         {:ok, metrics} <- parse_metrics(Map.fetch!(params, "metrics")),
         {:ok, filters} <- parse_filters(params["filters"]),
         {:ok, dimensions} <- parse_dimensions(params["dimensions"]),
         {:ok, order_by} <- parse_order_by(params["order_by"]),
         {:ok, pagination} <- parse_pagination(params["pagination"]),
         {:ok, include} <- parse_include(params["include"]) do
      {:ok,
       Plausible.Stats.ParsedQueryParams.new!(%{
         input_date_range: input_date_range,
         metrics: metrics,
         filters: filters,
         dimensions: dimensions,
         order_by: order_by,
         pagination: pagination,
         include: include
       })}
    end
  end

  def parse_date_range_pair(site, [from, to]) when is_binary(from) and is_binary(to) do
    with {:ok, date_range} <- date_range_from_date_strings(site, from, to) do
      {:ok, date_range |> DateTimeRange.to_timezone("Etc/UTC")}
    end
  end

  def parse_date_range_pair(_site, unknown), do: {:error, "Invalid date_range '#{i(unknown)}'."}

  defp date_range_from_date_strings(site, from, to) do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      {:ok, DateTimeRange.new!(from_date, to_date, site.timezone)}
    end
  end

  defp parse_metrics(metrics) when is_list(metrics) do
    parse_list(metrics, &parse_metric/1)
  end

  defp parse_metric(metric_str) do
    case Metrics.from_string(metric_str) do
      {:ok, metric} -> {:ok, metric}
      _ -> {:error, "Unknown metric '#{i(metric_str)}'."}
    end
  end

  def parse_filters(filters) when is_list(filters) do
    parse_list(filters, &parse_filter/1)
  end

  def parse_filters(nil), do: {:ok, []}

  defp parse_filter(filter) do
    with {:ok, operator} <- parse_operator(filter),
         {:ok, second} <- parse_filter_second(operator, filter),
         {:ok, rest} <- parse_filter_rest(operator, filter) do
      {:ok, [operator, second | rest]}
    end
  end

  defp parse_operator(["is" | _rest]), do: {:ok, :is}
  defp parse_operator(["is_not" | _rest]), do: {:ok, :is_not}
  defp parse_operator(["matches" | _rest]), do: {:ok, :matches}
  defp parse_operator(["matches_not" | _rest]), do: {:ok, :matches_not}
  defp parse_operator(["matches_wildcard" | _rest]), do: {:ok, :matches_wildcard}
  defp parse_operator(["matches_wildcard_not" | _rest]), do: {:ok, :matches_wildcard_not}
  defp parse_operator(["contains" | _rest]), do: {:ok, :contains}
  defp parse_operator(["contains_not" | _rest]), do: {:ok, :contains_not}
  defp parse_operator(["and" | _rest]), do: {:ok, :and}
  defp parse_operator(["or" | _rest]), do: {:ok, :or}
  defp parse_operator(["not" | _rest]), do: {:ok, :not}
  defp parse_operator(["has_done" | _rest]), do: {:ok, :has_done}
  defp parse_operator(["has_not_done" | _rest]), do: {:ok, :has_not_done}
  defp parse_operator(filter), do: {:error, "Unknown operator for filter '#{i(filter)}'."}

  def parse_filter_second(operator, [_, filters | _rest]) when operator in [:and, :or],
    do: parse_filters(filters)

  def parse_filter_second(operator, [_, filter | _rest])
      when operator in [:not, :has_done, :has_not_done],
      do: parse_filter(filter)

  def parse_filter_second(_operator, filter), do: parse_filter_dimension(filter)

  defp parse_filter_dimension([_operator, filter_dimension | _rest] = filter) do
    parse_filter_dimension_string(filter_dimension, "Invalid filter '#{i(filter)}")
  end

  defp parse_filter_dimension(filter), do: {:error, "Invalid filter '#{i(filter)}'."}

  defp parse_filter_rest(operator, filter)
       when operator in [
              :is,
              :is_not,
              :matches,
              :matches_not,
              :matches_wildcard,
              :matches_wildcard_not,
              :contains,
              :contains_not
            ] do
    with {:ok, clauses} <- parse_clauses_list(filter),
         {:ok, modifiers} <- parse_filter_modifiers(Enum.at(filter, 3)) do
      {:ok, [clauses | modifiers]}
    end
  end

  defp parse_filter_rest(operator, _filter)
       when operator in [:not, :and, :or, :has_done, :has_not_done],
       do: {:ok, []}

  defp parse_clauses_list([operator, dimension, list | _rest] = filter) when is_list(list) do
    all_strings? = Enum.all?(list, &is_binary/1)
    all_integers? = Enum.all?(list, &is_integer/1)

    case {dimension, all_strings?} do
      {"visit:city", false} when all_integers? ->
        {:ok, list}

      {"visit:country", true} when operator in ["is", "is_not"] ->
        if Enum.all?(list, &(String.length(&1) == 2)) do
          {:ok, list}
        else
          {:error,
           "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."}
        end

      {"segment", _} when all_integers? ->
        {:ok, list}

      {_, true} when dimension !== "segment" ->
        {:ok, list}

      _ ->
        {:error, "Invalid filter '#{i(filter)}'."}
    end
  end

  defp parse_clauses_list(filter), do: {:error, "Invalid filter '#{i(filter)}'"}

  defp parse_filter_modifiers(modifiers) when is_map(modifiers) do
    {:ok, [atomize_keys(modifiers)]}
  end

  defp parse_filter_modifiers(nil) do
    {:ok, []}
  end

  defp parse_input_date_range("realtime"), do: {:ok, :realtime}
  defp parse_input_date_range("30m"), do: {:ok, :realtime_30m}
  defp parse_input_date_range("day"), do: {:ok, :day}
  defp parse_input_date_range("month"), do: {:ok, :month}
  defp parse_input_date_range("year"), do: {:ok, :year}
  defp parse_input_date_range("all"), do: {:ok, :all}

  defp parse_input_date_range(shorthand) when is_binary(shorthand) do
    case Integer.parse(shorthand) do
      {n, "d"} when n > 0 and n <= 5_000 -> {:ok, {:last_n_days, n}}
      {n, "mo"} when n > 0 and n <= 100 -> {:ok, {:last_n_months, n}}
      _ -> {:error, "Invalid date_range #{i(shorthand)}"}
    end
  end

  defp parse_input_date_range([from, to]) when is_binary(from) and is_binary(to) do
    case parse_date_strings(from, to) do
      {:ok, dates} -> {:ok, dates}
      {:error, _} -> parse_timestamp_strings(from, to)
    end
  end

  defp parse_input_date_range(unknown) do
    {:error, "Invalid date_range #{i(unknown)}"}
  end

  defp parse_date_strings(from, to) do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      {:ok, {:date_range, from_date, to_date}}
    end
  end

  defp parse_timestamp_strings(from, to) do
    with {:ok, from_datetime, _offset} <- DateTime.from_iso8601(from),
         {:ok, to_datetime, _offset} <- DateTime.from_iso8601(to) do
      {:ok, {:datetime_range, from_datetime, to_datetime}}
    else
      _ -> {:error, "Invalid date_range '#{i([from, to])}'."}
    end
  end

  defp parse_dimensions(dimensions) when is_list(dimensions) do
    parse_list(
      dimensions,
      &parse_dimension_entry(&1, "Invalid dimensions '#{i(dimensions)}'")
    )
  end

  defp parse_dimensions(nil), do: {:ok, []}

  def parse_order_by(order_by) when is_list(order_by) do
    parse_list(order_by, &parse_order_by_entry/1)
  end

  def parse_order_by(nil), do: {:ok, nil}
  def parse_order_by(order_by), do: {:error, "Invalid order_by '#{i(order_by)}'."}

  defp parse_order_by_entry(entry) do
    with {:ok, value} <- parse_metric_or_dimension(entry),
         {:ok, order_direction} <- parse_order_direction(entry) do
      {:ok, {value, order_direction}}
    end
  end

  defp parse_dimension_entry(key, error_message) do
    case {
      parse_time(key),
      parse_filter_dimension_string(key)
    } do
      {{:ok, time}, _} -> {:ok, time}
      {_, {:ok, dimension}} -> {:ok, dimension}
      _ -> {:error, error_message}
    end
  end

  defp parse_metric_or_dimension([value, _] = entry) do
    case {
      parse_time(value),
      parse_metric(value),
      parse_filter_dimension_string(value)
    } do
      {{:ok, time}, _, _} -> {:ok, time}
      {_, {:ok, metric}, _} -> {:ok, metric}
      {_, _, {:ok, dimension}} -> {:ok, dimension}
      _ -> {:error, "Invalid order_by entry '#{i(entry)}'."}
    end
  end

  defp parse_time("time"), do: {:ok, "time"}
  defp parse_time("time:minute"), do: {:ok, "time:minute"}
  defp parse_time("time:hour"), do: {:ok, "time:hour"}
  defp parse_time("time:day"), do: {:ok, "time:day"}
  defp parse_time("time:week"), do: {:ok, "time:week"}
  defp parse_time("time:month"), do: {:ok, "time:month"}
  defp parse_time(_), do: :error

  defp parse_order_direction([_, "asc"]), do: {:ok, :asc}
  defp parse_order_direction([_, "desc"]), do: {:ok, :desc}
  defp parse_order_direction(entry), do: {:error, "Invalid order_by entry '#{i(entry)}'."}

  def parse_include(include) when is_map(include) do
    with {:ok, include} <- atomize_include_keys(include),
         {:ok, include} <- parse_comparison_date_range(include) do
      {:ok, Map.merge(@default_include, include)}
    end
  end

  def parse_include(nil), do: {:ok, @default_include}
  def parse_include(include), do: {:error, "Invalid include '#{i(include)}'."}

  defp atomize_include_keys(map) do
    expected_keys =
      @default_include
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)

    if Map.keys(map) |> Enum.all?(&(&1 in expected_keys)) do
      {:ok, atomize_keys(map)}
    else
      {:error, "Invalid include '#{i(map)}'."}
    end
  end

  defp parse_comparison_date_range(%{comparisons: %{date_range: date_range}} = include) do
    with {:ok, parsed_date_range} <- parse_input_date_range(date_range) do
      {:ok, put_in(include, [:comparisons, :date_range], parsed_date_range)}
    end
  end

  defp parse_comparison_date_range(include), do: {:ok, include}

  defp parse_pagination(pagination) when is_map(pagination) do
    {:ok, Map.merge(@default_pagination, atomize_keys(pagination))}
  end

  defp parse_pagination(nil), do: {:ok, @default_pagination}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      key = String.to_existing_atom(key)
      {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(value), do: value

  defp parse_filter_dimension_string(dimension, error_message \\ "") do
    case dimension do
      "event:props:" <> property_name ->
        if String.length(property_name) > 0 do
          {:ok, dimension}
        else
          {:error, error_message}
        end

      "event:" <> key ->
        if key in Filters.event_props() do
          {:ok, dimension}
        else
          {:error, error_message}
        end

      "visit:" <> key ->
        if key in Filters.visit_props() do
          {:ok, dimension}
        else
          {:error, error_message}
        end

      "segment" ->
        {:ok, dimension}

      _ ->
        {:error, error_message}
    end
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
