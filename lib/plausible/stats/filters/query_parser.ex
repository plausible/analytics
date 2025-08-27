defmodule Plausible.Stats.Filters.QueryParser do
  @moduledoc false

  use Plausible

  alias Plausible.Stats.{TableDecider, Filters, Metrics, DateTimeRange, JSONSchema, Time}

  @default_include %{
    imports: false,
    # `include.imports_meta` can be true even when `include.imports`
    # is false. Even if we don't want to include imported data, we
    # might still want to know whether imported data can be toggled
    # on/off on the dashboard.
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    comparisons: nil,
    legacy_time_on_page_cutoff: nil
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
         {:ok, preloaded_segments} <-
           Plausible.Segments.Filters.preload_needed_segments(site, filters),
         {:ok, filters} <-
           Plausible.Segments.Filters.resolve_segments(filters, preloaded_segments),
         {:ok, dimensions} <- parse_dimensions(Map.get(params, "dimensions", [])),
         {:ok, order_by} <- parse_order_by(Map.get(params, "order_by")),
         {:ok, include} <- parse_include(Map.get(params, "include", %{}), site),
         {:ok, pagination} <- parse_pagination(Map.get(params, "pagination", %{})),
         {preloaded_goals, revenue_warning, revenue_currencies} <-
           preload_goals_and_revenue(site, metrics, filters, dimensions),
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
           revenue_warning: revenue_warning,
           revenue_currencies: revenue_currencies
         },
         :ok <- validate_order_by(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- validate_toplevel_only_filter_dimension(query),
         :ok <- validate_special_metrics_filters(query),
         :ok <- validate_behavioral_filters(query),
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

  defp parse_time_range(site, "month", date, _now) do
    last = date |> Date.end_of_month()
    first = last |> Date.beginning_of_month()
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

  defp today(site), do: DateTime.now!(site.timezone) |> DateTime.to_date()

  defp parse_dimensions(dimensions) when is_list(dimensions) do
    parse_list(
      dimensions,
      &parse_dimension_entry(&1, "Invalid dimensions '#{i(dimensions)}'")
    )
  end

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
      {:ok, Map.merge(@default_include, include)}
    end
  end

  def parse_include(include, _site), do: {:error, "Invalid include '#{i(include)}'."}

  defp atomize_include_keys(map) do
    expected_keys = @default_include |> Map.keys() |> Enum.map(&Atom.to_string/1)

    if Map.keys(map) |> Enum.all?(&(&1 in expected_keys)) do
      {:ok, atomize_keys(map)}
    else
      {:error, "Invalid include '#{i(map)}'."}
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

  def preload_goals_and_revenue(site, metrics, filters, dimensions) do
    preloaded_goals =
      Plausible.Stats.Goals.preload_needed_goals(site, dimensions, filters)

    {revenue_warning, revenue_currencies} =
      preload_revenue(site, preloaded_goals, metrics, dimensions)

    {
      preloaded_goals,
      revenue_warning,
      revenue_currencies
    }
  end

  @only_toplevel ["event:goal", "event:hostname"]
  defp validate_toplevel_only_filter_dimension(query) do
    not_toplevel =
      query.filters
      |> Filters.dimensions_used_in_filters(min_depth: 1, behavioral_filters: :ignore)
      |> Enum.filter(&(&1 in @only_toplevel))

    if Enum.count(not_toplevel) > 0 do
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

  defp validate_behavioral_filters(query) do
    query.filters
    |> Filters.traverse(0, fn behavioral_depth, operator ->
      if operator in [:has_done, :has_not_done] do
        behavioral_depth + 1
      else
        behavioral_depth
      end
    end)
    |> Enum.reduce_while(:ok, fn {[_operator, dimension | _rest], behavioral_depth}, :ok ->
      cond do
        behavioral_depth == 0 ->
          # ignore non-behavioral filters
          {:cont, :ok}

        behavioral_depth > 1 ->
          {:halt,
           {:error,
            "Invalid filters. Behavioral filters (has_done, has_not_done) cannot be nested."}}

        not String.starts_with?(dimension, "event:") ->
          {:halt,
           {:error,
            "Invalid filters. Behavioral filters (has_done, has_not_done) can only be used with event dimension filters."}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_filtered_goals_exist(query) do
    # Note: We don't check :contains goal filters since it's acceptable if they match nothing.
    goal_filter_clauses =
      query.filters
      |> Filters.all_leaf_filters()
      |> Enum.flat_map(fn
        [:is, "event:goal", clauses] -> clauses
        _ -> []
      end)

    if length(goal_filter_clauses) > 0 do
      configured_goal_names =
        query.preloaded_goals.all
        |> Enum.map(&Plausible.Goal.display_name/1)

      validate_list(goal_filter_clauses, &validate_goal_filter(&1, configured_goal_names))
    else
      :ok
    end
  end

  on_ee do
    alias Plausible.Stats.Goal.Revenue

    def preload_revenue(site, preloaded_goals, metrics, dimensions) do
      Revenue.preload(site, preloaded_goals, metrics, dimensions)
    end

    defp validate_revenue_metrics_access(site, query) do
      if Revenue.requested?(query.metrics) and not Revenue.available?(site) do
        {:error, "The owner of this site does not have access to the revenue metrics feature."}
      else
        :ok
      end
    end
  else
    defp preload_revenue(_site, _preloaded_goals, _metrics, _dimensions), do: {nil, %{}}

    defp validate_revenue_metrics_access(_site, _query), do: :ok
  end

  defp validate_goal_filter(clause, configured_goal_names) do
    if Enum.member?(configured_goal_names, clause) do
      :ok
    else
      {:error,
       "Invalid filters. The goal `#{clause}` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"}
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
      TableDecider.validate_no_metrics_dimensions_conflict(query)
    end
  end

  defp validate_metric(metric, query) when metric in [:conversion_rate, :group_conversion_rate] do
    if Enum.member?(query.dimensions, "event:goal") or
         Filters.filtering_on_dimension?(query, "event:goal", behavioral_filters: :ignore) do
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

  defp validate_metric(:exit_rate = metric, query) do
    case {query.dimensions, TableDecider.sessions_join_events?(query)} do
      {["visit:exit_page"], false} ->
        :ok

      {["visit:exit_page"], true} ->
        {:error, "Metric `#{metric}` cannot be queried when filtering on event dimensions."}

      _ ->
        {:error,
         "Metric `#{metric}` requires a `\"visit:exit_page\"` dimension. No other dimensions are allowed."}
    end
  end

  defp validate_metric(:views_per_visit = metric, query) do
    cond do
      Filters.filtering_on_dimension?(query, "event:page", behavioral_filters: :ignore) ->
        {:error, "Metric `#{metric}` cannot be queried with a filter on `event:page`."}

      length(query.dimensions) > 0 ->
        {:error, "Metric `#{metric}` cannot be queried with `dimensions`."}

      true ->
        :ok
    end
  end

  defp validate_metric(:time_on_page = metric, query) do
    cond do
      Enum.member?(query.dimensions, "event:page") ->
        :ok

      Filters.filtering_on_dimension?(query, "event:page", behavioral_filters: :ignore) ->
        :ok

      true ->
        {:error, "Metric `#{metric}` can only be queried with event:page filters or dimensions."}
    end
  end

  defp validate_metric(_, _), do: :ok

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
