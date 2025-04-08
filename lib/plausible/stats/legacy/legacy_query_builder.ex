defmodule Plausible.Stats.Legacy.QueryBuilder do
  @moduledoc """
  Module used to parse URL search params to a valid Query, used to power the API for the dashboard.
  @deprecated
  """

  use Plausible

  alias Plausible.Stats.{Filters, Interval, Query, DateTimeRange}

  def from(site, params, debug_metadata, now \\ nil) do
    now = now || DateTime.utc_now(:second)

    query =
      Query
      |> struct!(
        now: now,
        debug_metadata: debug_metadata,
        site_id: site.id,
        site_native_stats_start_at: site.native_stats_start_at
      )
      |> put_period(site, params)
      |> put_timezone(site)
      |> put_dimensions(params)
      |> put_interval(params)
      |> put_parsed_filters(params)
      |> resolve_segments(site)
      |> preload_goals_and_revenue(site)
      |> put_order_by(params)
      |> put_include(site, params)
      |> Query.put_comparison_utc_time_range()
      |> Query.put_imported_opts(site)
      |> Query.set_time_on_page_data(site)

    on_ee do
      query = Plausible.Stats.Sampling.put_threshold(query, site, params)
    end

    query
  end

  defp resolve_segments(query, site) do
    with {:ok, preloaded_segments} <-
           Plausible.Segments.Filters.preload_needed_segments(site, query.filters),
         {:ok, filters} <-
           Plausible.Segments.Filters.resolve_segments(query.filters, preloaded_segments) do
      struct!(query,
        filters: filters
      )
    end
  end

  defp preload_goals_and_revenue(query, site) do
    {preloaded_goals, revenue_warning, revenue_currencies} =
      Plausible.Stats.Filters.QueryParser.preload_goals_and_revenue(
        site,
        query.metrics,
        query.filters,
        query.dimensions
      )

    struct!(query,
      preloaded_goals: preloaded_goals,
      revenue_warning: revenue_warning,
      revenue_currencies: revenue_currencies
    )
  end

  defp put_period(%Query{now: now} = query, _site, %{"period" => period})
       when period in ["realtime", "30m"] do
    duration_minutes =
      case period do
        "realtime" -> 5
        "30m" -> 30
      end

    first_datetime = DateTime.shift(now, minute: -duration_minutes)
    last_datetime = DateTime.shift(now, second: 5)

    datetime_range =
      DateTimeRange.new!(first_datetime, last_datetime) |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: period, utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "day"} = params) do
    date = parse_single_date(query, params)

    datetime_range =
      DateTimeRange.new!(date, date, site.timezone) |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "day", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => period} = params)
       when period in ["7d", "28d", "30d", "90d"] do
    {days, "d"} = Integer.parse(period)

    end_date = parse_single_date(query, params) |> Date.shift(day: -1)
    start_date = end_date |> Date.shift(day: 1 - days)

    datetime_range =
      DateTimeRange.new!(start_date, end_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: period, utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "month"} = params) do
    date = parse_single_date(query, params)
    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)

    datetime_range =
      DateTimeRange.new!(start_date, end_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "month", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "6mo"} = params) do
    end_date =
      parse_single_date(query, params)
      |> Timex.end_of_month()

    start_date =
      Date.shift(end_date, month: -5)
      |> Timex.beginning_of_month()

    datetime_range =
      DateTimeRange.new!(start_date, end_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "6mo", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "12mo"} = params) do
    end_date =
      parse_single_date(query, params)
      |> Timex.end_of_month()

    start_date =
      Date.shift(end_date, month: -11)
      |> Timex.beginning_of_month()

    datetime_range =
      DateTimeRange.new!(start_date, end_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "12mo", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "year"} = params) do
    end_date =
      parse_single_date(query, params)
      |> Timex.end_of_year()

    start_date = Timex.beginning_of_year(end_date)

    datetime_range =
      DateTimeRange.new!(start_date, end_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "year", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "all"}) do
    today = today(query)
    start_date = Plausible.Sites.stats_start_date(site) || today

    datetime_range =
      DateTimeRange.new!(start_date, today, site.timezone) |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "all", utc_time_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "custom", "from" => from, "to" => to} = params) do
    new_params =
      params
      |> Map.drop(["from", "to"])
      |> Map.put("date", Enum.join([from, to], ","))

    put_period(query, site, new_params)
  end

  defp put_period(query, site, %{"period" => "custom", "date" => date}) do
    [from, to] = String.split(date, ",")
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))

    datetime_range =
      DateTimeRange.new!(from_date, to_date, site.timezone)
      |> DateTimeRange.to_timezone("Etc/UTC")

    struct!(query, period: "custom", utc_time_range: datetime_range)
  end

  defp put_period(query, site, params) do
    put_period(query, site, Map.merge(params, %{"period" => "30d"}))
  end

  defp put_timezone(query, site) do
    struct!(query, timezone: site.timezone)
  end

  defp put_dimensions(query, params) do
    if not is_nil(params["property"]) do
      struct!(query, dimensions: [params["property"]])
    else
      struct!(query, dimensions: Map.get(params, "dimensions", []))
    end
  end

  defp put_include(query, site, params) do
    include = parse_include(site, params["include"])

    query
    |> struct!(include: include)
    |> Query.set_include(:comparisons, parse_comparison_params(site, params))
    |> Query.set_include(:imports, params["with_imported"] == "true")
  end

  @doc """
  ### Examples:
    iex> QueryBuilder.parse_order_by(nil)
    []

    iex> QueryBuilder.parse_order_by("")
    []

    iex> QueryBuilder.parse_order_by("0")
    []

    iex> QueryBuilder.parse_order_by("[}")
    []

    iex> QueryBuilder.parse_order_by(~s({"any":"object"}))
    []

    iex> QueryBuilder.parse_order_by(~s([["visitors","invalid"]]))
    []

    iex> QueryBuilder.parse_order_by(~s([["visitors","desc"]]))
    [{:visitors, :desc}]

    iex> QueryBuilder.parse_order_by(~s([["visitors","asc"],["visit:source","desc"]]))
    [{:visitors, :asc}, {"visit:source", :desc}]
  """
  def parse_order_by(order_by) do
    json_decode(order_by)
    |> unwrap([])
    |> Filters.QueryParser.parse_order_by()
    |> unwrap([])
  end

  @doc """
  ### Examples:
    iex> QueryBuilder.parse_include(%{}, nil)
    QueryParser.default_include()

    iex> QueryBuilder.parse_include(%{}, ~s({"total_rows": true}))
    Map.merge(QueryParser.default_include(), %{total_rows: true})
  """
  def parse_include(site, include) do
    json_decode(include)
    |> unwrap(%{})
    |> Filters.QueryParser.parse_include(site)
    |> unwrap(Filters.QueryParser.default_include())
  end

  defp json_decode(string) when is_binary(string) do
    Jason.decode(string)
  end

  defp json_decode(_other), do: :error

  defp unwrap({:ok, result}, _default), do: result
  defp unwrap(_, default), do: default

  defp put_order_by(query, %{} = params) do
    struct!(query, order_by: parse_order_by(params["order_by"]))
  end

  defp put_interval(%{:period => "all"} = query, params) do
    interval = Map.get(params, "interval", Interval.default_for_date_range(query.utc_time_range))
    struct!(query, interval: interval)
  end

  defp put_interval(query, params) do
    interval = Map.get(params, "interval", Interval.default_for_period(query.period))
    struct!(query, interval: interval)
  end

  defp put_parsed_filters(query, params) do
    struct!(query, filters: Filters.parse(params["filters"]))
  end

  defp today(query) do
    query.now |> Timex.to_date()
  end

  defp parse_single_date(query, params) do
    case params["date"] do
      "today" -> query.now |> Timex.to_date()
      date when is_binary(date) -> Date.from_iso8601!(date)
      _ -> today(query)
    end
  end

  def parse_comparison_params(_site, %{"period" => period}) when period in ~w(realtime all),
    do: nil

  def parse_comparison_params(_site, %{"comparison" => mode} = params)
      when mode in ["previous_period", "year_over_year"] do
    %{
      mode: mode,
      match_day_of_week: params["match_day_of_week"] == "true"
    }
  end

  def parse_comparison_params(site, %{"comparison" => "custom"} = params) do
    {:ok, date_range} =
      Filters.QueryParser.parse_date_range_pair(site, [
        params["compare_from"],
        params["compare_to"]
      ])

    %{
      mode: "custom",
      date_range: date_range,
      match_day_of_week: params["match_day_of_week"] == "true"
    }
  end

  def parse_comparison_params(_site, %{"compare" => "previous_period"}) do
    %{mode: "previous_period"}
  end

  def parse_comparison_params(_site, _options), do: nil
end
