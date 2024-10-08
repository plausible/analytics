defmodule Plausible.Stats.Filters.QueryParser do
  @moduledoc false

  alias Plausible.Stats.{TableDecider, Filters, Metrics, DateTimeRange, JSONSchema}
  alias Plausible.Stats.Filters.FiltersParser
  alias Plausible.Helpers.ListTraverse

  @default_include %{
    imports: false,
    time_labels: false,
    total_rows: false
  }

  @default_pagination %{
    limit: 10_000,
    offset: 0
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
         {:ok, raw_time_range} <-
           parse_time_range(site, Map.get(params, "date_range"), date, now),
         utc_time_range = raw_time_range |> DateTimeRange.to_timezone("Etc/UTC"),
         {:ok, metrics} <- parse_metrics(Map.get(params, "metrics", [])),
         {:ok, filters} <- FiltersParser.parse_filters(Map.get(params, "filters", [])),
         {:ok, dimensions} <- parse_dimensions(Map.get(params, "dimensions", [])),
         {:ok, order_by} <- parse_order_by(Map.get(params, "order_by")),
         {:ok, include} <- parse_include(Map.get(params, "include", %{})),
         {:ok, pagination} <- parse_pagination(Map.get(params, "pagination", %{})),
         preloaded_goals <- preload_goals_if_needed(site, filters, dimensions),
         query = %{
           metrics: metrics,
           filters: filters,
           utc_time_range: utc_time_range,
           dimensions: dimensions,
           order_by: order_by,
           timezone: site.timezone,
           preloaded_goals: preloaded_goals,
           include: include,
           pagination: pagination
         },
         :ok <- validate_order_by(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- validate_toplevel_only_filter_dimension(query),
         :ok <- validate_special_metrics_filters(query),
         :ok <- validate_filtered_goals_exist(query),
         :ok <- validate_segments_allowed(site, query, %{}),
         :ok <- validate_metrics(query),
         :ok <- validate_include(query) do
      {:ok, query}
    end
  end

  defp parse_metrics(metrics) when is_list(metrics) do
    ListTraverse.parse_list(metrics, &parse_metric/1)
  end

  defp parse_metric(metric_str) do
    case Metrics.from_string(metric_str) do
      {:ok, metric} -> {:ok, metric}
      _ -> {:error, "Unknown metric '#{i(metric_str)}'."}
    end
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

  defp parse_time_range(site, [from, to], _date, _now)
       when is_binary(from) and is_binary(to) do
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
    ListTraverse.parse_list(
      dimensions,
      &parse_dimension_entry(&1, "Invalid dimensions '#{i(dimensions)}'")
    )
  end

  defp parse_order_by(order_by) when is_list(order_by) do
    ListTraverse.parse_list(order_by, &parse_order_by_entry/1)
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
      FiltersParser.parse_filter_key_string(key)
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
      FiltersParser.parse_filter_key_string(value)
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
    {:ok, Map.merge(@default_include, atomize_keys(include))}
  end

  defp parse_pagination(pagination) when is_map(pagination) do
    {:ok, Map.merge(@default_pagination, atomize_keys(pagination))}
  end

  defp atomize_keys(map),
    do: Map.new(map, fn {key, value} -> {String.to_existing_atom(key), value} end)

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

  defp validate_segments_allowed(_site, _query, _available_segments) do
    :ok
  end

  defp validate_filtered_goals_exist(query) do
    # Note: Only works since event:goal is allowed as a top level filter
    goal_filter_clauses =
      Enum.flat_map(query.filters, fn
        [:is, "event:goal", clauses] -> clauses
        _ -> []
      end)

    if length(goal_filter_clauses) > 0 do
      ListTraverse.validate_list(
        goal_filter_clauses,
        &validate_goal_filter(&1, query.preloaded_goals)
      )
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
    with :ok <- ListTraverse.validate_list(query.metrics, &validate_metric(&1, query)) do
      validate_no_metrics_filters_conflict(query)
    end
  end

  defp validate_metric(metric, query) when metric in [:conversion_rate, :group_conversion_rate] do
    if Enum.member?(query.dimensions, "event:goal") or
         Filters.filtering_on_dimension?(query.filters, "event:goal") do
      :ok
    else
      {:error, "Metric `#{metric}` can only be queried with event:goal filters or dimensions."}
    end
  end

  defp validate_metric(:views_per_visit = metric, query) do
    cond do
      Filters.filtering_on_dimension?(query.filters, "event:page") ->
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
end
