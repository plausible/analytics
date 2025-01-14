defmodule Plausible.Stats.Query do
  use Plausible

  defstruct utc_time_range: nil,
            interval: nil,
            period: nil,
            dimensions: [],
            filters: [],
            sample_threshold: 20_000_000,
            include_imported: false,
            skip_imported_reason: nil,
            now: nil,
            latest_import_end_date: nil,
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
            site_native_stats_start_at: nil

  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{DateTimeRange, Filters, Imported, Legacy}

  @type t :: %__MODULE__{}

  def build(site, schema_type, params, debug_metadata) do
    with {:ok, query_data} <- Filters.QueryParser.parse(site, schema_type, params) do
      query =
        struct!(__MODULE__, Map.to_list(query_data))
        |> put_imported_opts(site, %{})
        |> struct!(
          now: DateTime.utc_now(:second),
          debug_metadata: debug_metadata,
          site_id: site.id,
          site_native_stats_start_at: site.native_stats_start_at
        )

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
      Enum.reject(query.filters, fn [_, filter_key | _rest] ->
        is_binary(filter_key) and Enum.any?(prefixes, &String.starts_with?(filter_key, &1))
      end)

    query
    |> struct!(filters: new_filters)
    |> refresh_imported_opts()
  end

  defp refresh_imported_opts(query) do
    put_imported_opts(query, nil, %{})
  end

  def put_imported_opts(query, site, params) do
    requested? = params["with_imported"] == "true" || query.include.imports

    latest_import_end_date =
      if site do
        site.latest_import_end_date
      else
        query.latest_import_end_date
      end

    query = struct!(query, latest_import_end_date: latest_import_end_date)

    case ensure_include_imported(query, requested?) do
      :ok ->
        struct!(query,
          include_imported: true,
          include: Map.put(query.include, :imports, true)
        )

      {:error, reason} ->
        struct!(query,
          include_imported: false,
          skip_imported_reason: reason,
          include: Map.put(query.include, :imports, requested?)
        )
    end
  end

  @spec ensure_include_imported(t(), boolean()) ::
          :ok | {:error, :no_imported_data | :out_of_range | :unsupported_query | :not_requested}
  def ensure_include_imported(query, requested?) do
    cond do
      not requested? ->
        {:error, :not_requested}

      is_nil(query.latest_import_end_date) ->
        {:error, :no_imported_data}

      query.period in ["realtime", "30m"] ->
        {:error, :unsupported_query}

      "time:minute" in query.dimensions or "time:hour" in query.dimensions ->
        {:error, :unsupported_interval}

      Date.after?(date_range(query).first, query.latest_import_end_date) ->
        {:error, :out_of_range}

      not Imported.schema_supports_query?(query) ->
        {:error, :unsupported_query}

      true ->
        :ok
    end
  end

  @spec trace(%__MODULE__{}, [atom()]) :: %__MODULE__{}
  def trace(%__MODULE__{} = query, metrics) do
    filter_keys =
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
      {"plausible.query.filter_keys", filter_keys},
      {"plausible.query.metrics", metrics}
    ])

    query
  end
end
