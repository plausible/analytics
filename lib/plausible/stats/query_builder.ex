defmodule Plausible.Stats.QueryBuilder do
  @moduledoc """
  A module used for building the Query struct from already parsed params.
  """

  use Plausible
  alias Plausible.Segments

  alias Plausible.Stats.{
    Query,
    ParsedQueryParams,
    Comparisons,
    Filters,
    Time,
    TableDecider,
    DateTimeRange,
    QueryError,
    QueryInclude
  }

  @doc """
  Runs various validations and builds a `%Query{}` from already parsed params.

  For convenience, the "parsed params" can also be given as a keyword list, in
  which case it gets turned in to `ParsedQueryParams` by the function itself.
  """
  def build(site, parsed_query_params, debug_metadata \\ %{})

  def build(site, %ParsedQueryParams{} = parsed_query_params, debug_metadata) do
    with {:ok, parsed_query_params} <- resolve_segments_in_filters(parsed_query_params, site),
         query = do_build(parsed_query_params, site, debug_metadata),
         :ok <- validate_order_by(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- validate_case_sensitive_filter_modifier(query),
         :ok <- validate_toplevel_only_filter_dimension(query),
         :ok <- validate_special_metrics_filters(query),
         :ok <- validate_behavioral_filters(query),
         :ok <- validate_filtered_goals_exist(query),
         :ok <- validate_revenue_metrics_access(site, query),
         :ok <- validate_metrics(query),
         :ok <- validate_include(query) do
      query =
        query
        |> set_time_on_page_data(site)
        |> put_comparison_utc_time_range()
        |> Query.put_imported_opts(site)

      on_ee do
        # NOTE: The Query API schema does not allow the sample_threshold param
        # and it looks like it's not used as a parameter anymore. We might want
        # to clean this up.
        query = Plausible.Stats.Sampling.put_threshold(query, site, %{})
      end

      {:ok, query}
    end
  end

  def build(site, params, debug_metadata) when is_list(params) do
    include = struct!(QueryInclude, Keyword.get(params, :include, []))
    parsed_query_params = struct!(ParsedQueryParams, Keyword.put(params, :include, include))

    build(site, parsed_query_params, debug_metadata)
  end

  def build!(site, params, debug_metadata \\ %{}) do
    case build(site, params, debug_metadata) do
      {:ok, query} ->
        query

      {:error, %QueryError{message: message}} ->
        raise "Failed to build query: #{inspect(message)}"
    end
  end

  defp resolve_segments_in_filters(%ParsedQueryParams{} = parsed_query_params, site) do
    with {:ok, preloaded_segments} <-
           Segments.Filters.preload_needed_segments(site, parsed_query_params.filters),
         {:ok, filters} <-
           Segments.Filters.resolve_segments(parsed_query_params.filters, preloaded_segments) do
      {:ok, struct!(parsed_query_params, filters: filters)}
    end
  end

  defp build_datetime_range(input_date_range, _site, _relative_date, now)
       when input_date_range in [:realtime, :realtime_30m] do
    duration_minutes =
      case input_date_range do
        :realtime -> 5
        :realtime_30m -> 30
      end

    first_datetime = DateTime.shift(now, minute: -duration_minutes)
    last_datetime = DateTime.shift(now, second: 5)

    DateTimeRange.new!(first_datetime, last_datetime)
  end

  defp build_datetime_range(:day, site, relative_date, _now) do
    DateTimeRange.new!(relative_date, relative_date, site.timezone)
  end

  defp build_datetime_range(:"24h", site, _relative_date, now) do
    to = now |> DateTime.shift_zone!(site.timezone) |> DateTime.shift_zone!("Etc/UTC")
    from = to |> DateTime.shift(hour: -24)

    DateTimeRange.new!(from, to)
  end

  defp build_datetime_range(:month, site, relative_date, _now) do
    first = relative_date |> Date.beginning_of_month()
    last = relative_date |> Date.end_of_month()
    DateTimeRange.new!(first, last, site.timezone)
  end

  defp build_datetime_range(:year, site, relative_date, _now) do
    first = relative_date |> Plausible.Times.beginning_of_year()
    last = relative_date |> Plausible.Times.end_of_year()
    DateTimeRange.new!(first, last, site.timezone)
  end

  defp build_datetime_range(:all, site, relative_date, _now) do
    start_date = Plausible.Sites.stats_start_date(site) || relative_date
    DateTimeRange.new!(start_date, relative_date, site.timezone)
  end

  defp build_datetime_range({:last_n_days, n}, site, relative_date, _now) do
    last = relative_date |> Date.add(-1)
    first = relative_date |> Date.add(-n)
    DateTimeRange.new!(first, last, site.timezone)
  end

  defp build_datetime_range({:last_n_months, n}, site, relative_date, _now) do
    last = relative_date |> Date.shift(month: -1) |> Date.end_of_month()
    first = relative_date |> Date.shift(month: -n) |> Date.beginning_of_month()
    DateTimeRange.new!(first, last, site.timezone)
  end

  defp build_datetime_range({:date_range, from, to}, site, _relative_date, _now) do
    DateTimeRange.new!(from, to, site.timezone)
  end

  defp build_datetime_range({:datetime_range, from, to}, _site, _relative_date, _now) do
    DateTimeRange.new!(from, to)
  end

  defp do_build(parsed_query_params, site, debug_metadata) do
    now = Plausible.Stats.Query.Test.get_fixed_now()

    %ParsedQueryParams{
      input_date_range: input_date_range,
      relative_date: relative_date,
      metrics: metrics,
      filters: filters,
      dimensions: dimensions
    } = parsed_query_params

    relative_date = relative_date || today_from_now(site, now)

    utc_time_range =
      input_date_range
      |> build_datetime_range(site, relative_date, now)
      |> DateTimeRange.to_timezone("Etc/UTC")

    {preloaded_goals, revenue_warning, revenue_currencies} =
      preload_goals_and_revenue(site, metrics, filters, dimensions)

    consolidated_site_ids = get_consolidated_site_ids(site)

    struct!(%Query{},
      now: now,
      input_date_range: input_date_range,
      utc_time_range: utc_time_range,
      site_id: site.id,
      metrics: metrics,
      dimensions: dimensions,
      filters: filters,
      order_by: parsed_query_params.order_by,
      pagination: parsed_query_params.pagination,
      include: parsed_query_params.include,
      site_native_stats_start_at: site.native_stats_start_at,
      consolidated_site_ids: consolidated_site_ids,
      timezone: site.timezone,
      preloaded_goals: preloaded_goals,
      revenue_warning: revenue_warning,
      revenue_currencies: revenue_currencies,
      debug_metadata: debug_metadata
    )
  end

  on_ee do
    def get_consolidated_site_ids(%Plausible.Site{} = site) do
      if Plausible.Sites.consolidated?(site) do
        Plausible.ConsolidatedView.Cache.get(site.domain)
      end
    end
  else
    def get_consolidated_site_ids(_site), do: nil
  end

  def set_time_on_page_data(query, site) do
    struct!(query,
      time_on_page_data: %{
        new_metric_visible: Plausible.Stats.TimeOnPage.new_time_on_page_visible?(site),
        cutoff_date: site.legacy_time_on_page_cutoff
      }
    )
  end

  def put_comparison_utc_time_range(%Query{include: %{compare: nil}} = query), do: query

  def put_comparison_utc_time_range(%Query{} = query) do
    datetime_range = Comparisons.get_comparison_utc_time_range(query)
    struct!(query, comparison_utc_time_range: datetime_range)
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

  on_ee do
    alias Plausible.Stats.Goal.Revenue

    def preload_revenue(site, preloaded_goals, metrics, dimensions) do
      Revenue.preload(site, preloaded_goals, metrics, dimensions)
    end

    defp validate_revenue_metrics_access(site, query) do
      if Revenue.requested?(query.metrics) and not Revenue.available?(site) do
        {:error,
         %QueryError{
           code: :feature_access,
           message: "The owner of this site does not have access to the revenue metrics feature."
         }}
      else
        :ok
      end
    end
  else
    defp preload_revenue(_site, _preloaded_goals, _metrics, _dimensions), do: {nil, %{}}

    defp validate_revenue_metrics_access(_site, _query), do: :ok
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
           %QueryError{
             code: :invalid_order_by,
             message:
               "Invalid order_by entry '#{i(invalid_entry)}'. Entry is not a queried metric or dimension."
           }}
      end
    else
      :ok
    end
  end

  @pattern_filter_operators [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not]
  defp validate_case_sensitive_filter_modifier(query) do
    invalid_filter =
      query.filters
      |> Filters.all_leaf_filters()
      |> Enum.find(fn filter ->
        case filter do
          [operator, _, _, modifiers] when operator in @pattern_filter_operators ->
            is_map_key(modifiers, :case_insensitive)

          _ ->
            false
        end
      end)

    if invalid_filter do
      {:error,
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. The case_sensitive modifier is not allowed with pattern operators (#{i(invalid_filter)})"
       }}
    else
      :ok
    end
  end

  @only_toplevel ["event:goal", "event:hostname"]
  defp validate_toplevel_only_filter_dimension(query) do
    not_toplevel =
      query.filters
      |> Filters.dimensions_used_in_filters(min_depth: 1, behavioral_filters: :ignore)
      |> Enum.filter(&(&1 in @only_toplevel))

    if Enum.count(not_toplevel) > 0 do
      {:error,
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. Dimension `#{List.first(not_toplevel)}` can only be filtered at the top level."
       }}
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
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. When `conversion_rate` or `group_conversion_rate` metrics are used, custom property filters can only be used on top level."
       }}
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
            %QueryError{
              code: :invalid_filters,
              message:
                "Invalid filters. Behavioral filters (has_done, has_not_done) cannot be nested."
            }}}

        not String.starts_with?(dimension, "event:") ->
          {:halt,
           {:error,
            %QueryError{
              code: :invalid_filters,
              message:
                "Invalid filters. Behavioral filters (has_done, has_not_done) can only be used with event dimension filters."
            }}}

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

  defp validate_goal_filter(clause, configured_goal_names) do
    if Enum.member?(configured_goal_names, clause) do
      :ok
    else
      {:error,
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. The goal `#{clause}` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
       }}
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
      {:error,
       %QueryError{
         code: :feature_access,
         message: "The owner of this site does not have access to the custom properties feature."
       }}
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
      {:error,
       %QueryError{
         code: :invalid_metrics,
         message: "Metric `#{metric}` can only be queried with event:goal filters or dimensions."
       }}
    end
  end

  defp validate_metric(:scroll_depth = metric, query) do
    page_dimension? = Enum.member?(query.dimensions, "event:page")
    toplevel_page_filter? = not is_nil(Filters.get_toplevel_filter(query, "event:page"))

    if page_dimension? or toplevel_page_filter? do
      :ok
    else
      {:error,
       %QueryError{
         code: :invalid_metrics,
         message: "Metric `#{metric}` can only be queried with event:page filters or dimensions."
       }}
    end
  end

  defp validate_metric(:exit_rate = metric, query) do
    case {query.dimensions, TableDecider.sessions_join_events?(query)} do
      {["visit:exit_page"], false} ->
        :ok

      {["visit:exit_page"], true} ->
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message: "Metric `#{metric}` cannot be queried when filtering on event dimensions."
         }}

      _ ->
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message:
             "Metric `#{metric}` requires a `\"visit:exit_page\"` dimension. No other dimensions are allowed."
         }}
    end
  end

  defp validate_metric(:views_per_visit = metric, query) do
    cond do
      Filters.filtering_on_dimension?(query, "event:page", behavioral_filters: :ignore) ->
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message: "Metric `#{metric}` cannot be queried with a filter on `event:page`."
         }}

      length(query.dimensions) > 0 ->
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message: "Metric `#{metric}` cannot be queried with `dimensions`."
         }}

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
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message:
             "Metric `#{metric}` can only be queried with event:page filters or dimensions."
         }}
    end
  end

  defp validate_metric(_, _), do: :ok

  defp validate_include(query) do
    time_dimension? = Enum.any?(query.dimensions, &Time.time_dimension?/1)

    if query.include.time_labels and not time_dimension? do
      {:error,
       %QueryError{
         code: :invalid_include,
         message: "Invalid include.time_labels: requires a time dimension."
       }}
    else
      :ok
    end
  end

  defp today_from_now(site, now) do
    now |> DateTime.shift_zone!(site.timezone) |> DateTime.to_date()
  end

  defp i(value), do: inspect(value, charlists: :as_lists)

  defp validate_list(list, parser_function) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case parser_function.(value) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
