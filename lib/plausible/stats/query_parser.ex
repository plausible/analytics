defmodule Plausible.Stats.QueryParser do
  @moduledoc false

  use Plausible

  alias Plausible.Stats.{Filters, Metrics, DateTimeRange, JSONSchema}

  def parse(site, schema_type, params, now \\ nil) when is_map(params) do
    now = now || Plausible.Stats.Query.Test.get_fixed_now()
    date = now |> DateTime.shift_zone!(site.timezone) |> DateTime.to_date()

    with :ok <- JSONSchema.validate(schema_type, params),
         {:ok, date, now} <- parse_date(site, Map.get(params, "date"), date, now),
         {:ok, raw_time_range} <-
           parse_time_range(site, Map.get(params, "date_range"), date, now),
         utc_time_range = raw_time_range |> DateTimeRange.to_timezone("Etc/UTC"),
         {:ok, metrics} <- parse_metrics(Map.fetch!(params, "metrics")),
         {:ok, filters} <- parse_filters(params["filters"]),
         {:ok, dimensions} <- parse_dimensions(params["dimensions"]),
         {:ok, order_by} <- parse_order_by(params["order_by"]),
         {:ok, pagination} <- parse_pagination(params["pagination"]),
         {:ok, include} <- parse_include(params["include"], site) do
      {:ok,
       Plausible.Stats.ParsedQueryParams.new!(%{
         now: now,
         utc_time_range: utc_time_range,
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

  def parse_filters(nil), do: {:ok, nil}

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

  defp parse_date(site, date_string, _date, _now) when is_binary(date_string) do
    with {:ok, date} <- Date.from_iso8601(date_string),
         {:ok, datetime} <- DateTime.new(date, ~T[00:00:00], site.timezone) do
      {:ok, date, datetime}
    else
      {:gap, just_before, _just_after} -> just_before
      {:ambiguous, first_datetime, _second_datetime} -> first_datetime
      _ -> {:error, "Invalid date '#{date_string}'."}
    end
  end

  defp parse_date(_site, _date_string, date, now) do
    {:ok, date, now}
  end

  defp parse_time_range(_site, date_range, _date, now) when date_range in ["realtime", "30m"] do
    duration_minutes =
      case date_range do
        "realtime" -> 5
        "30m" -> 30
      end

    first_datetime = DateTime.shift(now, minute: -duration_minutes)
    last_datetime = DateTime.shift(now, second: 5)

    {:ok, DateTimeRange.new!(first_datetime, last_datetime)}
  end

  defp parse_time_range(site, "day", date, _now) do
    {:ok, DateTimeRange.new!(date, date, site.timezone)}
  end

  defp parse_time_range(site, "month", date, _now) do
    last = date |> Date.end_of_month()
    first = last |> Date.beginning_of_month()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "year", date, _now) do
    last = date |> Plausible.Times.end_of_year()
    first = last |> Plausible.Times.beginning_of_year()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "all", date, _now) do
    start_date = Plausible.Sites.stats_start_date(site) || date

    {:ok, DateTimeRange.new!(start_date, date, site.timezone)}
  end

  defp parse_time_range(site, shorthand, date, _now) when is_binary(shorthand) do
    case Integer.parse(shorthand) do
      {n, "d"} when n > 0 and n <= 5_000 ->
        last = date |> Date.add(-1)
        first = date |> Date.add(-n)
        {:ok, DateTimeRange.new!(first, last, site.timezone)}

      {n, "mo"} when n > 0 and n <= 100 ->
        last = date |> Date.shift(month: -1) |> Date.end_of_month()
        first = date |> Date.shift(month: -n) |> Date.beginning_of_month()
        {:ok, DateTimeRange.new!(first, last, site.timezone)}

      _ ->
        {:error, "Invalid date_range #{i(shorthand)}"}
    end
  end

  defp parse_time_range(site, [from, to], _date, _now) when is_binary(from) and is_binary(to) do
    case date_range_from_date_strings(site, from, to) do
      {:ok, date_range} -> {:ok, date_range}
      {:error, _} -> date_range_from_timestamps(from, to)
    end
  end

  defp parse_time_range(_site, unknown, _date, _now),
    do: {:error, "Invalid date_range #{i(unknown)}"}

  defp date_range_from_date_strings(site, from, to) do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      {:ok, DateTimeRange.new!(from_date, to_date, site.timezone)}
    end
  end

  defp date_range_from_timestamps(from, to) do
    with {:ok, from_datetime, _offset} <- DateTime.from_iso8601(from),
         {:ok, to_datetime, _offset} <- DateTime.from_iso8601(to) do
      {:ok, DateTimeRange.new!(from_datetime, to_datetime)}
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

  defp parse_dimensions(nil), do: {:ok, nil}

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

  def parse_include(include, site) when is_map(include) do
    with {:ok, include} <- atomize_include_keys(include),
         {:ok, include} <- update_comparisons_date_range(include, site) do
      {:ok, include}
    end
  end

  def parse_include(nil, _site), do: {:ok, nil}
  def parse_include(include, _site), do: {:error, "Invalid include '#{i(include)}'."}

  defp atomize_include_keys(map) do
    expected_keys =
      Plausible.Stats.ParsedQueryParams.default_include()
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)

    if Map.keys(map) |> Enum.all?(&(&1 in expected_keys)) do
      {:ok, atomize_keys(map)}
    else
      {:error, "Invalid include '#{i(map)}'."}
    end
  end

  defp update_comparisons_date_range(%{comparisons: %{date_range: date_range}} = include, site) do
    with {:ok, parsed_date_range} <- parse_time_range(site, date_range, nil, nil) do
      {:ok, put_in(include, [:comparisons, :date_range], parsed_date_range)}
    end
  end

  defp update_comparisons_date_range(include, _site), do: {:ok, include}

  defp parse_pagination(pagination) when is_map(pagination) do
    {:ok,
     Map.merge(Plausible.Stats.ParsedQueryParams.default_pagination(), atomize_keys(pagination))}
  end

  defp parse_pagination(nil), do: {:ok, nil}

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
