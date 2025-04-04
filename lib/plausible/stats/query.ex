defmodule Plausible.Stats.Query do
  use Plausible

  defstruct utc_time_range: nil,
            comparison_utc_time_range: nil,
            interval: nil,
            period: nil,
            dimensions: [],
            filters: [],
            sample_threshold: 20_000_000,
            imports_exist: false,
            imports_in_range: [],
            include_imported: false,
            skip_imported_reason: nil,
            now: nil,
            metrics: [],
            order_by: nil,
            timezone: nil,
            legacy_breakdown: false,
            preloaded_goals: [],
            include: Plausible.Stats.Filters.QueryParser.default_include(),
            debug_metadata: %{},
            pagination: nil,
            # Revenue metric specific metadata
            revenue_currencies: %{},
            revenue_warning: nil,
            remove_unavailable_revenue_metrics: false,
            site_id: nil,
            site_native_stats_start_at: nil,
            # Contains information to determine how to combine legacy and new time on page metrics
            time_on_page_data: %{}

  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{DateTimeRange, Filters, Imported, Legacy, Comparisons}

  @type t :: %__MODULE__{}

  def build(site, schema_type, params, debug_metadata) do
    with {:ok, query_data} <- Filters.QueryParser.parse(site, schema_type, params) do
      query =
        %__MODULE__{
          now: DateTime.utc_now(:second),
          debug_metadata: debug_metadata,
          site_id: site.id,
          site_native_stats_start_at: site.native_stats_start_at
        }
        |> struct!(Map.to_list(query_data))
        |> set_time_on_page_data(site)
        |> put_comparison_utc_time_range()
        |> put_imported_opts(site)

      on_ee do
        query = Plausible.Stats.Sampling.put_threshold(query, site, params)
      end

      {:ok, query}
    end
  end

  @doc """
  Builds query from old-style params. New code should prefer Query.build
  """
  def from(site, params, debug_metadata \\ %{}, now \\ nil) do
    Legacy.QueryBuilder.from(site, params, debug_metadata, now)
  end

  def date_range(query, options \\ []) do
    date_range = DateTimeRange.to_date_range(query.utc_time_range, query.timezone)

    if Keyword.get(options, :trim_trailing) do
      today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()

      Date.range(
        date_range.first,
        clamp(today, date_range)
      )
    else
      date_range
    end
  end

  defp clamp(date, date_range) do
    cond do
      date in date_range -> date
      Date.before?(date, date_range.first) -> date_range.first
      Date.after?(date, date_range.last) -> date_range.last
    end
  end

  def set(query, keywords) do
    new_query = struct!(query, keywords)

    if Keyword.has_key?(keywords, :include_imported) do
      new_query
    else
      refresh_imported_opts(new_query)
    end
  end

  def set_include(query, key, value) do
    struct!(query, include: Map.put(query.include, key, value))
  end

  def add_filter(query, filter) do
    query
    |> struct!(filters: query.filters ++ [filter])
    |> refresh_imported_opts()
  end

  @doc """
  Removes top level filters matching any of passed prefix from the query.

  Note that this doesn't handle cases with AND/OR/NOT and as such is discouraged
  from use.
  """
  def remove_top_level_filters(query, prefixes) do
    new_filters =
      Enum.reject(query.filters, fn [_, dimension_or_filter_tree | _rest] ->
        is_binary(dimension_or_filter_tree) and
          Enum.any?(prefixes, &String.starts_with?(dimension_or_filter_tree, &1))
      end)

    query
    |> struct!(filters: new_filters)
    |> refresh_imported_opts()
  end

  defp refresh_imported_opts(query) do
    put_imported_opts(query, nil)
  end

  def put_comparison_utc_time_range(%__MODULE__{include: %{comparisons: nil}} = query), do: query

  def put_comparison_utc_time_range(%__MODULE__{include: %{comparisons: comparison_opts}} = query) do
    datetime_range = Comparisons.get_comparison_utc_time_range(query, comparison_opts)
    struct!(query, comparison_utc_time_range: datetime_range)
  end

  def put_imported_opts(query, site) do
    requested? = query.include.imports

    query =
      if site do
        struct!(query,
          imports_exist: Plausible.Imported.any_completed_imports?(site),
          imports_in_range: get_imports_in_range(site, query)
        )
      else
        query
      end

    skip_imported_reason = get_skip_imported_reason(query)

    struct!(query,
      include_imported: requested? and is_nil(skip_imported_reason),
      skip_imported_reason: skip_imported_reason
    )
  end

  defp get_imports_in_range(_site, %__MODULE__{period: period})
       when period in ["realtime", "30m"] do
    []
  end

  defp get_imports_in_range(site, query) do
    in_range = Plausible.Imported.completed_imports_in_query_range(site, query)

    in_comparison_range =
      if is_map(query.include.comparisons) do
        comparison_query = Comparisons.get_comparison_query(query)
        Plausible.Imported.completed_imports_in_query_range(site, comparison_query)
      else
        []
      end

    in_comparison_range ++ in_range
  end

  def set_time_on_page_data(query, site) do
    struct!(query,
      time_on_page_data: %{
        new_metric_visible: Plausible.Stats.TimeOnPage.new_time_on_page_visible?(site),
        cutoff_date: site.legacy_time_on_page_cutoff
      }
    )
  end

  @spec get_skip_imported_reason(t()) ::
          nil | :no_imported_data | :out_of_range | :unsupported_query
  def get_skip_imported_reason(query) do
    cond do
      not query.imports_exist ->
        :no_imported_data

      query.imports_in_range == [] ->
        :out_of_range

      "time:minute" in query.dimensions or "time:hour" in query.dimensions ->
        :unsupported_interval

      not Imported.schema_supports_query?(query) ->
        :unsupported_query

      true ->
        nil
    end
  end

  @spec trace(%__MODULE__{}, [atom()]) :: %__MODULE__{}
  def trace(%__MODULE__{} = query, metrics) do
    filter_dimensions =
      query.filters
      |> Plausible.Stats.Filters.dimensions_used_in_filters()
      |> Enum.sort()
      |> Enum.uniq()
      |> Enum.join(";")

    metrics = metrics |> Enum.sort() |> Enum.join(";")

    Tracer.set_attributes([
      {"plausible.query.interval", query.interval},
      {"plausible.query.period", query.period},
      {"plausible.query.dimensions", query.dimensions |> Enum.join(";")},
      {"plausible.query.include_imported", query.include_imported},
      {"plausible.query.filter_keys", filter_dimensions},
      {"plausible.query.metrics", metrics}
    ])

    query
  end
end
