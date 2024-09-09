defmodule Plausible.Stats.Legacy.QueryBuilder do
  @moduledoc """
  Module used to parse URL search params to a valid Query, used to power the API for the dashboard.
  @deprecated
  """

  use Plausible

  alias Plausible.Stats.{Filters, Interval, Query, DateTimeRange, Metrics}

  def from(site, params, debug_metadata) do
    now = DateTime.utc_now(:second)

    query =
      Query
      |> struct!(now: now, debug_metadata: debug_metadata)
      |> put_period(site, params)
      |> put_timezone()
      |> put_dimensions(params)
      |> put_interval(params)
      |> put_parsed_filters(params)
      |> put_preloaded_goals(site)
      |> put_order_by(params)
      |> Query.put_experimental_reduced_joins(site, params)
      |> Query.put_imported_opts(site, params)

    on_ee do
      query = Plausible.Stats.Sampling.put_threshold(query, params)
    end

    query
  end

  defp put_preloaded_goals(query, site) do
    goals =
      Plausible.Stats.Filters.QueryParser.preload_goals_if_needed(
        site,
        query.filters,
        query.dimensions
      )

    struct!(query, preloaded_goals: goals)
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

    struct!(query, period: period, date_range: DateTimeRange.new!(first_datetime, last_datetime))
  end

  defp put_period(query, site, %{"period" => "day"} = params) do
    date = parse_single_date(site.timezone, params)
    datetime_range = DateTimeRange.new!(date, date, site.timezone)

    struct!(query, period: "day", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "7d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Date.shift(day: -6)
    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "7d", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "30d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Date.shift(day: -30)
    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "30d", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "month"} = params) do
    date = parse_single_date(site.timezone, params)
    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)
    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "month", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "6mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Date.shift(end_date, month: -5)
      |> Timex.beginning_of_month()

    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "6mo", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "12mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Date.shift(end_date, month: -11)
      |> Timex.beginning_of_month()

    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "12mo", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "year"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_year()

    start_date = Timex.beginning_of_year(end_date)
    datetime_range = DateTimeRange.new!(start_date, end_date, site.timezone)

    struct!(query, period: "year", date_range: datetime_range)
  end

  defp put_period(query, site, %{"period" => "all"}) do
    today = today(site.timezone)
    start_date = Plausible.Sites.stats_start_date(site) || today
    datetime_range = DateTimeRange.new!(start_date, today, site.timezone)

    struct!(query, period: "all", date_range: datetime_range)
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
    datetime_range = DateTimeRange.new!(from_date, to_date, site.timezone)

    struct!(query, period: "custom", date_range: datetime_range)
  end

  defp put_period(query, site, params) do
    put_period(query, site, Map.merge(params, %{"period" => "30d"}))
  end

  defp put_timezone(query) do
    struct!(query, timezone: query.date_range.first.time_zone)
  end

  defp put_dimensions(query, params) do
    if not is_nil(params["property"]) do
      struct!(query, dimensions: [params["property"]])
    else
      struct!(query, dimensions: Map.get(params, "dimensions", []))
    end
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
  def parse_order_by(order_by) when is_binary(order_by) do
    case Jason.decode(order_by) do
      {:ok, parsed} when is_list(parsed) ->
        Enum.flat_map(parsed, &parse_order_by_pair/1)

      _ ->
        []
    end
  end

  def parse_order_by(_) do
    []
  end

  defp parse_order_by_pair([metric_or_dimension, direction]) when direction in ["asc", "desc"] do
    case Metrics.from_string(metric_or_dimension) do
      {:ok, metric} -> [{metric, String.to_existing_atom(direction)}]
      :error -> [{metric_or_dimension, String.to_existing_atom(direction)}]
    end
  end

  defp parse_order_by_pair(_) do
    []
  end

  defp put_order_by(query, %{} = params) do
    struct!(query, order_by: parse_order_by(params["order_by"]))
  end

  defp put_interval(%{:period => "all"} = query, params) do
    interval = Map.get(params, "interval", Interval.default_for_date_range(query.date_range))
    struct!(query, interval: interval)
  end

  defp put_interval(query, params) do
    interval = Map.get(params, "interval", Interval.default_for_period(query.period))
    struct!(query, interval: interval)
  end

  defp put_parsed_filters(query, params) do
    struct!(query, filters: Filters.parse(params["filters"]))
  end

  defp today(tz) do
    DateTime.now!(tz) |> Timex.to_date()
  end

  defp parse_single_date(tz, params) do
    case params["date"] do
      "today" -> DateTime.now!(tz) |> Timex.to_date()
      date when is_binary(date) -> Date.from_iso8601!(date)
      _ -> today(tz)
    end
  end
end
