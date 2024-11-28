defmodule Plausible.Stats.Filters.QueryParser do
  @moduledoc false

  use Plausible

  alias Plausible.Stats.{TableDecider, Filters, Metrics, DateTimeRange, JSONSchema, Time}

  @default_include %{
    imports: false,
    time_labels: false,
    total_rows: false,
    comparisons: nil
  }

  @default_pagination %{
    limit: 10_000,
    offset: 0
  }

  def default_include(), do: @default_include

  def parse(site, schema_type, params, now \\ nil) when is_map(params) do
    {now, date} =
      if now do
        {now, DateTime.shift_zone!(now, site.timezone) |> DateTime.to_date()}
      else
        {DateTime.utc_now(:second), today(site)}
      end

    with :ok <- JSONSchema.validate(schema_type, params),
         {:ok, date} <- parse_date(site, Map.get(params, "date"), date),
         {:ok, raw_time_range} <-
           parse_time_range(site, Map.get(params, "date_range"), date, now),
         utc_time_range = raw_time_range |> DateTimeRange.to_timezone("Etc/UTC"),
         {:ok, metrics} <- parse_metrics(Map.get(params, "metrics", [])),
         {:ok, filters} <- parse_filters(Map.get(params, "filters", [])),
         {:ok, dimensions} <- parse_dimensions(Map.get(params, "dimensions", [])),
         {:ok, order_by} <- parse_order_by(Map.get(params, "order_by")),
         {:ok, include} <- parse_include(site, Map.get(params, "include", %{})),
         {:ok, pagination} <- parse_pagination(Map.get(params, "pagination", %{})),
         {preloaded_goals, revenue_currencies} <-
           preload_needed_goals(site, metrics, filters, dimensions),
         query = %{
           metrics: metrics,
           filters: filters,
           utc_time_range: utc_time_range,
           dimensions: dimensions,
           order_by: order_by,
           timezone: site.timezone,
           include: include,
           pagination: pagination,
           preloaded_goals: preloaded_goals,
           revenue_currencies: revenue_currencies
         },
         :ok <- validate_order_by(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- validate_toplevel_only_filter_dimension(query),
         :ok <- validate_special_metrics_filters(query),
         :ok <- validate_filtered_goals_exist(query),
         :ok <- validate_revenue_metrics_access(site, query),
         :ok <- validate_metrics(query),
         :ok <- validate_include(query) do
      {:ok, query}
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

  def parse_filters(_invalid_metrics), do: {:error, "Invalid filters passed."}

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
  defp parse_operator(["not" | _rest]), do: {:ok, :not}
  defp parse_operator(["and" | _rest]), do: {:ok, :and}
  defp parse_operator(["or" | _rest]), do: {:ok, :or}
  defp parse_operator(filter), do: {:error, "Unknown operator for filter '#{i(filter)}'."}

  def parse_filter_second(:not, [_, filter | _rest]), do: parse_filter(filter)

  def parse_filter_second(operator, [_, filters | _rest]) when operator in [:and, :or],
    do: parse_filters(filters)

  def parse_filter_second(_operator, filter), do: parse_filter_key(filter)

  defp parse_filter_key([_operator, filter_key | _rest] = filter) do
    parse_filter_key_string(filter_key, "Invalid filter '#{i(filter)}")
  end

  defp parse_filter_key(filter), do: {:error, "Invalid filter '#{i(filter)}'."}

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
       when operator in [:not, :and, :or],
       do: {:ok, []}

  defp parse_clauses_list([operator, filter_key, list | _rest] = filter) when is_list(list) do
    all_strings? = Enum.all?(list, &is_binary/1)
    all_integers? = Enum.all?(list, &is_integer/1)

    case {filter_key, all_strings?} do
      {"visit:city", false} when all_integers? ->
        {:ok, list}

      {"visit:country", true} when operator in ["is", "is_not"] ->
        if Enum.all?(list, &(String.length(&1) == 2)) do
          {:ok, list}
        else
          {:error,
           "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."}
        end

      {_, true} ->
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

  defp parse_date(_site, date_string, _date) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "Invalid date '#{date_string}'."}
    end
  end

  defp parse_date(_site, _date_string, date) do
    {:ok, date}
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

  defp parse_time_range(site, "7d", date, _now) do
    first = date |> Date.add(-6)
    {:ok, DateTimeRange.new!(first, date, site.timezone)}
  end

  defp parse_time_range(site, "30d", date, _now) do
    first = date |> Date.add(-30)
    {:ok, DateTimeRange.new!(first, date, site.timezone)}
  end

  defp parse_time_range(site, "month", date, _now) do
    last = date |> Date.end_of_month()
    first = last |> Date.beginning_of_month()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "6mo", date, _now) do
    last = date |> Date.end_of_month()

    first =
      last
      |> Date.shift(month: -5)
      |> Date.beginning_of_month()

    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "12mo", date, _now) do
    last = date |> Date.end_of_month()

    first =
      last
      |> Date.shift(month: -11)
      |> Date.beginning_of_month()

    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "year", date, _now) do
    last = date |> Timex.end_of_year()
    first = last |> Timex.beginning_of_year()
    {:ok, DateTimeRange.new!(first, last, site.timezone)}
  end

  defp parse_time_range(site, "all", date, _now) do
    start_date = Plausible.Sites.stats_start_date(site) || date

    {:ok, DateTimeRange.new!(start_date, date, site.timezone)}
  end

  defp parse_time_range(site, [from, to], _date, _now) when is_binary(from) and is_binary(to) do
    case date_range_from_date_strings(site, from, to) do
      {:ok, date_range} -> {:ok, date_range}
      {:error, _} -> date_range_from_timestamps(from, to)
    end
  end

  defp parse_time_range(_site, unknown, _date, _now),
    do: {:error, "Invalid date_range '#{i(unknown)}'."}

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

  defp parse_include(site, include) when is_map(include) do
    parsed =
      include
      |> atomize_keys()
      |> update_comparisons_date_range(site)

    with {:ok, include} <- parsed do
      {:ok, Map.merge(@default_include, include)}
    end
  end

  defp update_comparisons_date_range(%{comparisons: %{date_range: date_range}} = include, site) do
    with {:ok, parsed_date_range} <- parse_date_range_pair(site, date_range) do
      {:ok, put_in(include, [:comparisons, :date_range], parsed_date_range)}
    end
  end

  defp update_comparisons_date_range(include, _site), do: {:ok, include}

  defp parse_pagination(pagination) when is_map(pagination) do
    {:ok, Map.merge(@default_pagination, atomize_keys(pagination))}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      key = String.to_existing_atom(key)
      {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(value), do: value

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

  def preload_needed_goals(site, metrics, filters, dimensions) do
    goal_filters? =
      Enum.any?(filters, fn [_, filter_key | _rest] -> filter_key == "event:goal" end)

    if goal_filters? or Enum.member?(dimensions, "event:goal") do
      goals = Plausible.Goals.Filters.preload_needed_goals(site, filters)

      {
        goals,
        preload_revenue_currencies(site, goals, metrics, dimensions)
      }
    else
      {[], %{}}
    end
  end

  @only_toplevel ["event:goal", "event:hostname"]
  defp validate_toplevel_only_filter_dimension(query) do
    not_toplevel = Filters.dimensions_used_in_filters(query.filters, min_depth: 1)

    if Enum.any?(not_toplevel, &(&1 in @only_toplevel)) do
      {:error,
       "Invalid filters. Dimension `#{List.first(not_toplevel)}` can only be filtered at the top level."}
    else
      :ok
    end
  end

  @special_metrics [:conversion_rate, :group_conversion_rate]
  defp validate_special_metrics_filters(query) do
    special_metric? = Enum.any?(@special_metrics, &(&1 in query.metrics))

    deep_custom_property? =
      query.filters
      |> Filters.dimensions_used_in_filters(min_depth: 1)
      |> Enum.any?(fn dimension -> String.starts_with?(dimension, "event:props:") end)

    if special_metric? and deep_custom_property? do
      {:error,
       "Invalid filters. When `conversion_rate` or `group_conversion_rate` metrics are used, custom property filters can only be used on top level."}
    else
      :ok
    end
  end

  defp validate_filtered_goals_exist(query) do
    # Note: Only works since event:goal is allowed as a top level filter
    goal_filter_clauses =
      Enum.flat_map(query.filters, fn
        [:is, "event:goal", clauses | _rest] -> clauses
        _ -> []
      end)

    if length(goal_filter_clauses) > 0 do
      validate_list(goal_filter_clauses, &validate_goal_filter(&1, query.preloaded_goals))
    else
      :ok
    end
  end

  on_ee do
    alias Plausible.Stats.Goal.Revenue

    defdelegate preload_revenue_currencies(site, preloaded_goals, metrics, dimensions),
      to: Plausible.Stats.Goal.Revenue

    defp validate_revenue_metrics_access(site, query) do
      if Revenue.requested?(query.metrics) and not Revenue.available?(site) do
        {:error, "The owner of this site does not have access to the revenue metrics feature."}
      else
        :ok
      end
    end
  else
    defp preload_revenue_currencies(_site, _preloaded_goals, _metrics, _dimensions), do: %{}

    defp validate_revenue_metrics_access(_site, _query), do: :ok
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
      |> Filters.dimensions_used_in_filters()
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
         Filters.filtering_on_dimension?(query, "event:goal") do
      :ok
    else
      {:error, "Metric `#{metric}` can only be queried with event:goal filters or dimensions."}
    end
  end

  defp validate_metric(:scroll_depth = metric, query) do
    page_dimension? = Enum.member?(query.dimensions, "event:page")
    toplevel_page_filter? = not is_nil(Filters.get_toplevel_filter(query, "event:page"))

    if page_dimension? or toplevel_page_filter? do
      :ok
    else
      {:error, "Metric `#{metric}` can only be queried with event:page filters or dimensions."}
    end
  end

  defp validate_metric(:views_per_visit = metric, query) do
    cond do
      Filters.filtering_on_dimension?(query, "event:page") ->
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
    time_dimension? = Enum.any?(query.dimensions, &Time.time_dimension?/1)

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
