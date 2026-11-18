defmodule Plausible.Stats.Query.Builder do
  @moduledoc """
  A module used for building the Query struct from already parsed params.
  """

  use Plausible
  alias Plausible.Segments

  alias Plausible.Stats.{
    Query,
    Comparisons,
    Filters,
    Time,
    TableDecider,
    DateTimeRange,
    QueryError,
    QueryPeriod
  }

  alias Plausible.Stats.Query.ParsedParams

  @doc """
  Runs various validations and builds a `%Query{}` from already parsed params.

  For convenience, the "parsed params" can also be given as a keyword list, in
  which case it gets turned in to `ParsedParams` by the function itself.
  """
  def build(site, parsed_query_params, debug_metadata \\ %{})

  def build(site, %ParsedParams{} = parsed_query_params, debug_metadata) do
    with {:ok, parsed_query_params} <- resolve_segments_in_filters(parsed_query_params, site),
         {:ok, query} <- do_build(parsed_query_params, site, debug_metadata),
         :ok <- validate_order_by(query),
         :ok <- validate_custom_props_access(site, query),
         :ok <- Filters.Validations.validate_case_sensitive_modifier(query.filters),
         :ok <- Filters.Validations.validate_toplevel_only(query.filters),
         :ok <- validate_time_dimension_granularity(query),
         :ok <- validate_special_metrics_filters(query),
         :ok <- Filters.Validations.validate_behavioral(query.filters),
         :ok <- validate_filtered_goals_exist(query, parsed_query_params),
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
    include = struct!(Query.Include, Keyword.get(params, :include, []))
    parsed_query_params = struct!(ParsedParams, Keyword.put(params, :include, include))

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

  defp resolve_segments_in_filters(%ParsedParams{} = parsed_query_params, site) do
    with {:ok, filters} <- Segments.Filters.preload_and_resolve(site, parsed_query_params.filters) do
      {:ok, struct!(parsed_query_params, filters: filters)}
    end
  end

  defp do_build(parsed_query_params, site, debug_metadata) do
    parsed_query_params
    |> ParsedParams.to_query!()
    |> set_now()
    |> set_utc_time_range(site, Map.get(parsed_query_params, :relative_date))
    |> set_preloaded_goals_and_revenue(site)
    |> Query.set(
      site_id: site.id,
      site_native_stats_start_at: site.native_stats_start_at,
      timezone: site.timezone,
      consolidated_site_ids: get_consolidated_site_ids(site),
      debug_metadata: debug_metadata
    )
    |> maybe_drop_revenue_metrics()
  end

  defp set_now(%Query{now: nil} = query), do: Query.set(query, now: DateTime.utc_now(:second))
  defp set_now(query), do: query

  defp set_utc_time_range(query, site, relative_date) do
    utc_time_range =
      QueryPeriod.build_utc_range_for_site(query.input_date_range, site, relative_date, query.now)

    Query.set(query, utc_time_range: utc_time_range)
  end

  defp set_preloaded_goals_and_revenue(query, site) do
    {preloaded_goals, revenue_warning, revenue_currencies} =
      preload_goals_and_revenue(site, query.metrics, query.filters, query.dimensions)

    Query.set(query,
      preloaded_goals: preloaded_goals,
      revenue_warning: revenue_warning,
      revenue_currencies: revenue_currencies
    )
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

    defp maybe_drop_revenue_metrics(
           %Query{
             include: %Query.Include{drop_unavailable_revenue_metrics: true},
             revenue_currencies: revenue_currencies
           } = query
         )
         when map_size(revenue_currencies) == 0 do
      if Enum.all?(query.metrics, &(&1 in Revenue.revenue_metrics())) do
        {:error,
         %QueryError{
           code: :all_metrics_dropped,
           message: "Revenue metrics were dropped and no other metrics were left to query."
         }}
      else
        {:ok, Query.set(query, metrics: query.metrics -- Revenue.revenue_metrics())}
      end
    end

    defp maybe_drop_revenue_metrics(%Query{} = query), do: {:ok, query}
  else
    defp preload_revenue(_site, _preloaded_goals, _metrics, _dimensions), do: {nil, %{}}

    defp validate_revenue_metrics_access(_site, _query), do: :ok

    defp maybe_drop_revenue_metrics(query), do: {:ok, query}
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

  @max_hours_for_minute_interval 30

  defp validate_time_dimension_granularity(query) do
    if Time.time_dimension(query) == "time:minute" and
         DateTimeRange.length(query.utc_time_range, :minute) > @max_hours_for_minute_interval * 60 do
      {:error,
       %QueryError{
         code: :invalid_dimensions,
         message:
           "Invalid dimensions. Dimension `time:minute` is only supported for time ranges up to 30 hours."
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

  defp validate_filtered_goals_exist(_query, %ParsedParams{skip_goal_existence_check: true}),
    do: :ok

  defp validate_filtered_goals_exist(query, %ParsedParams{}) do
    # Note: We don't check :contains goal filters since it's acceptable if they match nothing.
    goal_filter_clauses =
      query.filters
      |> Filters.all_leaf_filters()
      |> Enum.flat_map(fn
        [:is, "event:goal", clauses] -> clauses
        _ -> []
      end)

    if goal_filter_clauses != [] do
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

    with :ok <- Filters.Validations.validate_custom_props_access(query.filters, allowed_props) do
      validate_custom_props_dimensions_access(query.dimensions, allowed_props)
    end
  end

  defp validate_custom_props_dimensions_access(_dimensions, :all), do: :ok

  defp validate_custom_props_dimensions_access(dimensions, allowed_props) do
    valid? =
      Enum.all?(dimensions, fn
        "event:props:" <> prop -> prop in allowed_props
        _ -> true
      end)

    if valid?, do: :ok, else: {:error, Filters.Validations.custom_props_access_error()}
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
    case {Enum.sort(query.dimensions), TableDecider.sessions_join_events?(query)} do
      {["visit:exit_page"], false} ->
        :ok

      {["visit:exit_page", "visit:exit_page_hostname"], false} ->
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

      Enum.any?(query.dimensions, &(not Time.time_dimension?(&1))) ->
        {:error,
         %QueryError{
           code: :invalid_metrics,
           message: "Metric `#{metric}` cannot be queried with non-time dimensions."
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
