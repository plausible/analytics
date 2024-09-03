defmodule Plausible.Stats.Filters.QueryParser do
  @moduledoc false

  alias Plausible.Stats.{TableDecider, Filters, Query, Metrics, DateTimeRange, JSONSchema}

  @default_include %{
    imports: false,
    time_labels: false
  }

  def parse(site, schema_type, params, now \\ nil) when is_map(params) do
    {now, date} =
      if now do
        {now, DateTime.shift_zone!(now, site.timezone) |> DateTime.to_date()}
      else
        {DateTime.utc_now(:second), today(site)}
      end

    with :ok <- JSONSchema.validate(schema_type, params),
         {:ok, date} <- parse_date(site, Map.get(params, "date"), date),
         {:ok, date_range} <- parse_date_range(site, Map.get(params, "date_range"), date, now),
         {:ok, metrics} <- parse_metrics(Map.get(params, "metrics", [])),
         {:ok, filters} <- parse_filters(Map.get(params, "filters", [])),
         {:ok, dimensions} <- parse_dimensions(Map.get(params, "dimensions", [])),
         {:ok, order_by} <- parse_order_by(Map.get(params, "order_by")),
         {:ok, include} <- parse_include(Map.get(params, "include", %{})),
         preloaded_goals <- preload_goals_if_needed(site, filters, dimensions),
         query = %{
           metrics: metrics,
           filters: filters,
           date_range: date_range,
           dimensions: dimensions,
           order_by: order_by,
           timezone: date_range.first.time_zone,
           preloaded_goals: preloaded_goals,
           include: include
         },
         :ok <- validate_order_by(query),
         :ok <- validate_goal_filters(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- validate_metrics(query),
         :ok <- validate_include(query) do
      {:ok, query}
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

  def parse_filters(_invalid_metrics), do: {:error, "Invalid filters passed."}

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
  defp parse_operator(["contains" | _rest]), do: {:ok, :contains}
  defp parse_operator(["does_not_contain" | _rest]), do: {:ok, :does_not_contain}
  defp parse_operator(filter), do: {:error, "Unknown operator for filter '#{i(filter)}'."}

  defp parse_filter_key([_operator, filter_key | _rest] = filter) do
    parse_filter_key_string(filter_key, "Invalid filter '#{i(filter)}")
  end

  defp parse_filter_key(filter), do: {:error, "Invalid filter '#{i(filter)}'."}

  defp parse_filter_rest(operator, filter)
       when operator in [:is, :is_not, :matches, :does_not_match, :contains, :does_not_contain],
       do: parse_clauses_list(filter)

  defp parse_clauses_list([operation, filter_key, list] = filter) when is_list(list) do
    all_strings? = Enum.all?(list, &is_binary/1)
    all_integers? = Enum.all?(list, &is_integer/1)

    case {filter_key, all_strings?} do
      {"visit:city", false} when all_integers? ->
        {:ok, [list]}

      {"visit:country", true} when operation in ["is", "is_not"] ->
        if Enum.all?(list, &(String.length(&1) == 2)) do
          {:ok, [list]}
        else
          {:error,
           "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."}
        end

      {_, true} ->
        {:ok, [list]}

      _ ->
        {:error, "Invalid filter '#{i(filter)}'."}
    end
  end

  defp parse_clauses_list(filter), do: {:error, "Invalid filter '#{i(filter)}'"}

  defp parse_date(_site, date_string, _date) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "Invalid date '#{date_string}'."}
    end
  end

  defp parse_date(_site, _date_string, date) do
    {:ok, date}
  end

  defp parse_date_range(_site, date_range, _date, now) when date_range in ["realtime", "30m"] do
    duration_minutes =
      case date_range do
        "realtime" -> 5
        "30m" -> 30
      end

    first_datetime = DateTime.shift(now, minute: -duration_minutes)
    last_datetime = DateTime.shift(now, second: 5)

    {:ok, DateTimeRange.new!(first_datetime, last_datetime)}
  end

  defp parse_date_range(site, "day", date, _now) do
    {:ok, DateTimeRange.new!(date, date, site.timezone)}
  end

  defp parse_date_range(site, "7d", date, _now) do
    first = date |> Date.add(-6)
    {:ok, DateTimeRange.new!(first, date, site.timezone)}
  end

  defp parse_date_range(site, "30d", date, _now) do
    first = date |> Date.add(-30)
    {:ok, DateTimeRange.new!(first, date, site.timezone)}
  end

  defp parse_date_range(site, "month", date, _now) do
    last = date |> Date.end_of_month()
    first = last |> Date.beginning_of_month()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_date_range(site, "6mo", date, _now) do
    last = date |> Date.end_of_month()

    first =
      last
      |> Date.shift(month: -5)
      |> Date.beginning_of_month()

    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_date_range(site, "12mo", date, _now) do
    last = date |> Date.end_of_month()

    first =
      last
      |> Date.shift(month: -11)
      |> Date.beginning_of_month()

    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_date_range(site, "year", date, _now) do
    last = date |> Timex.end_of_year()
    first = last |> Timex.beginning_of_year()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_date_range(site, "all", date, _now) do
    start_date = Plausible.Sites.stats_start_date(site) || date

    {:ok, DateTimeRange.new!(start_date, date, site.timezone)}
  end

  defp parse_date_range(site, [from, to], _date, _now)
       when is_binary(from) and is_binary(to) do
    case date_range_from_date_strings(site, from, to) do
      {:ok, date_range} -> {:ok, date_range}
      {:error, _} -> date_range_from_timestamps(from, to)
    end
  end

  defp parse_date_range(_site, unknown, _date, _now),
    do: {:error, "Invalid date_range '#{i(unknown)}'."}

  defp date_range_from_date_strings(site, from, to) do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      {:ok, DateTimeRange.new!(from_date, to_date, site.timezone)}
    end
  end

  defp date_range_from_timestamps(from, to) do
    with {:ok, from_datetime} <- datetime_from_timestamp(from),
         {:ok, to_datetime} <- datetime_from_timestamp(to),
         true <- from_datetime.time_zone == to_datetime.time_zone do
      {:ok, DateTimeRange.new!(from_datetime, to_datetime)}
    else
      _ -> {:error, "Invalid date_range '#{i([from, to])}'."}
    end
  end

  defp datetime_from_timestamp(timestamp_string) do
    with [timestamp, timezone] <- String.split(timestamp_string),
         {:ok, naive_datetime} <- NaiveDateTime.from_iso8601(timestamp) do
      DateTime.from_naive(naive_datetime, timezone)
    end
  end

  defp today(site), do: DateTime.now!(site.timezone) |> DateTime.to_date()

  defp parse_dimensions(dimensions) when is_list(dimensions) do
    parse_list(
      dimensions,
      &parse_dimension_entry(&1, "Invalid dimensions '#{i(dimensions)}'")
    )
  end

  defp parse_order_by(order_by) when is_list(order_by) do
    parse_list(order_by, &parse_order_by_entry/1)
  end

  defp parse_order_by(nil), do: {:ok, nil}
  defp parse_order_by(order_by), do: {:error, "Invalid order_by '#{i(order_by)}'."}

  defp parse_order_by_entry(entry) do
    with {:ok, value} <- parse_metric_or_dimension(entry),
         {:ok, order_direction} <- parse_order_direction(entry) do
      {:ok, {value, order_direction}}
    end
  end

  defp parse_dimension_entry(key, error_message) do
    case {
      parse_time(key),
      parse_filter_key_string(key)
    } do
      {{:ok, time}, _} -> {:ok, time}
      {_, {:ok, filter_key}} -> {:ok, filter_key}
      _ -> {:error, error_message}
    end
  end

  defp parse_metric_or_dimension([value, _] = entry) do
    case {
      parse_time(value),
      parse_metric(value),
      parse_filter_key_string(value)
    } do
      {{:ok, time}, _, _} -> {:ok, time}
      {_, {:ok, metric}, _} -> {:ok, metric}
      {_, _, {:ok, dimension}} -> {:ok, dimension}
      _ -> {:error, "Invalid order_by entry '#{i(entry)}'."}
    end
  end

  defp parse_time("time"), do: {:ok, "time"}
  defp parse_time("time:hour"), do: {:ok, "time:hour"}
  defp parse_time("time:day"), do: {:ok, "time:day"}
  defp parse_time("time:week"), do: {:ok, "time:week"}
  defp parse_time("time:month"), do: {:ok, "time:month"}
  defp parse_time(_), do: :error

  defp parse_order_direction([_, "asc"]), do: {:ok, :asc}
  defp parse_order_direction([_, "desc"]), do: {:ok, :desc}
  defp parse_order_direction(entry), do: {:error, "Invalid order_by entry '#{i(entry)}'."}

  defp parse_include(include) when is_map(include) do
    with {:ok, parsed_include_list} <- parse_list(include, &parse_include_value/1) do
      include = Map.merge(@default_include, Enum.into(parsed_include_list, %{}))

      {:ok, include}
    end
  end

  defp parse_include_value({"imports", value}) when is_boolean(value),
    do: {:ok, {:imports, value}}

  defp parse_include_value({"time_labels", value}) when is_boolean(value),
    do: {:ok, {:time_labels, value}}

  defp parse_filter_key_string(filter_key, error_message \\ "") do
    case filter_key do
      "event:props:" <> property_name ->
        if String.length(property_name) > 0 do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

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

  defp validate_order_by(query) do
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
           "Invalid order_by entry '#{i(invalid_entry)}'. Entry is not a queried metric or dimension."}
      end
    else
      :ok
    end
  end

  def preload_goals_if_needed(site, filters, dimensions) do
    goal_filters? =
      Enum.any?(filters, fn [_, filter_key | _rest] -> filter_key == "event:goal" end)

    if goal_filters? or Enum.member?(dimensions, "event:goal") do
      Plausible.Goals.for_site(site)
    else
      []
    end
  end

  defp validate_goal_filters(query) do
    goal_filter_clauses =
      Enum.flat_map(query.filters, fn
        [:is, "event:goal", clauses] -> clauses
        _ -> []
      end)

    if length(goal_filter_clauses) > 0 do
      validate_list(goal_filter_clauses, &validate_goal_filter(&1, query.preloaded_goals))
    else
      :ok
    end
  end

  defp validate_goal_filter(clause, configured_goals) do
    configured_goal_names =
      Enum.map(configured_goals, fn goal -> Plausible.Goal.display_name(goal) end)

    if Enum.member?(configured_goal_names, clause) do
      :ok
    else
      {:error,
       "The goal `#{clause}` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"}
    end
  end

  defp validate_custom_props_access(site, query) do
    allowed_props = Plausible.Props.allowed_for(site, bypass_setup?: true)

    validate_custom_props_access(site, query, allowed_props)
  end

  defp validate_custom_props_access(_site, _query, :all), do: :ok

  defp validate_custom_props_access(_site, query, allowed_props) do
    valid? =
      query.filters
      |> Enum.map(fn [_operation, filter_key | _rest] -> filter_key end)
      |> Enum.concat(query.dimensions)
      |> Enum.all?(fn
        "event:props:" <> prop -> prop in allowed_props
        _ -> true
      end)

    if valid? do
      :ok
    else
      {:error, "The owner of this site does not have access to the custom properties feature."}
    end
  end

  defp validate_metrics(query) do
    with :ok <- validate_list(query.metrics, &validate_metric(&1, query)) do
      validate_no_metrics_filters_conflict(query)
    end
  end

  defp validate_metric(metric, query) when metric in [:conversion_rate, :group_conversion_rate] do
    if Enum.member?(query.dimensions, "event:goal") or
         not is_nil(Query.get_filter(query, "event:goal")) do
      :ok
    else
      {:error, "Metric `#{metric}` can only be queried with event:goal filters or dimensions."}
    end
  end

  defp validate_metric(:views_per_visit = metric, query) do
    cond do
      not is_nil(Query.get_filter(query, "event:page")) ->
        {:error, "Metric `#{metric}` cannot be queried with a filter on `event:page`."}

      length(query.dimensions) > 0 ->
        {:error, "Metric `#{metric}` cannot be queried with `dimensions`."}

      true ->
        :ok
    end
  end

  defp validate_metric(_, _), do: :ok

  defp validate_no_metrics_filters_conflict(query) do
    {_event_metrics, sessions_metrics, _other_metrics} =
      TableDecider.partition_metrics(query.metrics, query)

    if Enum.empty?(sessions_metrics) or
         not event_dimensions_not_allowing_session_metrics?(query.dimensions) do
      :ok
    else
      {:error,
       "Session metric(s) `#{sessions_metrics |> Enum.join(", ")}` cannot be queried along with event dimensions."}
    end
  end

  defp event_dimensions_not_allowing_session_metrics?(dimensions) do
    Enum.any?(dimensions, fn
      "event:page" -> false
      "event:" <> _ -> true
      _ -> false
    end)
  end

  defp validate_include(query) do
    time_dimension? = Enum.any?(query.dimensions, &String.starts_with?(&1, "time"))

    if query.include.time_labels and not time_dimension? do
      {:error, "Invalid include.time_labels: requires a time dimension."}
    else
      :ok
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

  defp validate_list(list, parser_function) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case parser_function.(value) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
