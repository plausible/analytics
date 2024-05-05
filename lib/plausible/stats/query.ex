defmodule Plausible.Stats.Query do
  use Plausible

  defstruct date_range: nil,
            interval: nil,
            period: nil,
            property: nil,
            filters: %{},
            sample_threshold: 20_000_000,
            imported_data_requested: false,
            include_imported: false,
            now: nil,
            experimental_session_count?: false,
            experimental_reduced_joins?: false

  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{Filters, Interval, Imported}

  @type t :: %__MODULE__{}

  def from(site, params) do
    now = NaiveDateTime.utc_now(:second)

    query =
      __MODULE__
      |> struct!(now: now)
      |> put_experimental_session_count(site, params)
      |> put_experimental_reduced_joins(site, params)
      |> put_period(site, params)
      |> put_breakdown_property(params)
      |> put_interval(params)
      |> put_parsed_filters(params)
      |> put_imported_opts(site, params)

    on_ee do
      query = Plausible.Stats.Sampling.put_threshold(query, params)
    end

    query
  end

  defp put_experimental_session_count(query, site, params) do
    if Map.has_key?(params, "experimental_session_count") do
      struct!(query,
        experimental_session_count?: Map.get(params, "experimental_session_count") == "true"
      )
    else
      struct!(query,
        experimental_session_count?: FunWithFlags.enabled?(:experimental_session_count, for: site)
      )
    end
  end

  defp put_experimental_reduced_joins(query, site, params) do
    if Map.has_key?(params, "experimental_reduced_joins") do
      struct!(query,
        experimental_reduced_joins?: Map.get(params, "experimental_reduced_joins") == "true"
      )
    else
      struct!(query,
        experimental_reduced_joins?: FunWithFlags.enabled?(:experimental_reduced_joins, for: site)
      )
    end
  end

  defp put_period(query, site, %{"period" => "realtime"}) do
    date = today(site.timezone)

    struct!(query, period: "realtime", date_range: Date.range(date, date))
  end

  defp put_period(query, site, %{"period" => "day"} = params) do
    date = parse_single_date(site.timezone, params)

    struct!(query, period: "day", date_range: Date.range(date, date))
  end

  defp put_period(query, site, %{"period" => "7d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -6)

    struct!(
      query,
      period: "7d",
      date_range: Date.range(start_date, end_date)
    )
  end

  defp put_period(query, site, %{"period" => "30d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -30)

    struct!(query, period: "30d", date_range: Date.range(start_date, end_date))
  end

  defp put_period(query, site, %{"period" => "month"} = params) do
    date = parse_single_date(site.timezone, params)

    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)

    struct!(query,
      period: "month",
      date_range: Date.range(start_date, end_date)
    )
  end

  defp put_period(query, site, %{"period" => "6mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -5)
      |> Timex.beginning_of_month()

    struct!(query,
      period: "6mo",
      date_range: Date.range(start_date, end_date)
    )
  end

  defp put_period(query, site, %{"period" => "12mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -11)
      |> Timex.beginning_of_month()

    struct!(query,
      period: "12mo",
      date_range: Date.range(start_date, end_date)
    )
  end

  defp put_period(query, site, %{"period" => "year"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_year()

    start_date = Timex.beginning_of_year(end_date)

    struct!(query,
      period: "year",
      date_range: Date.range(start_date, end_date)
    )
  end

  defp put_period(query, site, %{"period" => "all"}) do
    now = today(site.timezone)
    start_date = Plausible.Sites.stats_start_date(site) || now

    struct!(query,
      period: "all",
      date_range: Date.range(start_date, now)
    )
  end

  defp put_period(query, site, %{"period" => "custom", "from" => from, "to" => to} = params) do
    new_params =
      params
      |> Map.drop(["from", "to"])
      |> Map.put("date", Enum.join([from, to], ","))

    put_period(query, site, new_params)
  end

  defp put_period(query, _site, %{"period" => "custom", "date" => date}) do
    [from, to] = String.split(date, ",")
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))

    struct!(query,
      period: "custom",
      date_range: Date.range(from_date, to_date)
    )
  end

  defp put_period(query, site, params) do
    put_period(query, site, Map.merge(params, %{"period" => "30d"}))
  end

  defp put_breakdown_property(query, params) do
    struct!(query, property: params["property"])
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

  def put_filter(query, filter) do
    struct!(query,
      filters: query.filters ++ [filter]
    )
  end

  def remove_event_filters(query, opts) do
    new_filters =
      Enum.filter(query.filters, fn {_, filter_key, _} ->
        cond do
          :page in opts && filter_key == "event:page" -> false
          :goal in opts && filter_key == "event:goal" -> false
          :props in opts && filter_key && String.starts_with?(filter_key, "event:props:") -> false
          true -> true
        end
      end)

    struct!(query, filters: new_filters)
  end

  def has_event_filters?(query) do
    Enum.any?(query.filters, fn
      {_, "event:" <> _, _} -> true
      _ -> false
    end)
  end

  def get_filter_by_prefix(query, prefix) do
    Enum.find(query.filters, fn {_op, prop, _value} ->
      String.starts_with?(prop, prefix)
    end)
  end

  def get_all_filters_by_prefix(query, prefix) do
    Enum.filter(query.filters, fn {_op, prop, _value} ->
      String.starts_with?(prop, prefix)
    end)
  end

  # :TODO: Replace these callsites with proper mapping over query.filters
  def get_filter(query, name) do
    Enum.find(query.filters, fn {_, prop, _} ->
      prop == name
    end)
  end

  defp today(tz) do
    Timex.now(tz) |> Timex.to_date()
  end

  defp parse_single_date(tz, params) do
    case params["date"] do
      "today" -> Timex.now(tz) |> Timex.to_date()
      date when is_binary(date) -> Date.from_iso8601!(date)
      _ -> today(tz)
    end
  end

  defp put_imported_opts(query, site, params) do
    requested? = params["with_imported"] == "true"

    struct!(query,
      imported_data_requested: requested?,
      include_imported: include_imported?(query, site, requested?)
    )
  end

  @spec include_imported?(t(), Plausible.Site.t(), boolean()) :: boolean()
  def include_imported?(query, site, requested?) do
    cond do
      is_nil(site.latest_import_end_date) -> false
      Date.after?(query.date_range.first, site.latest_import_end_date) -> false
      not Imported.schema_supports_query?(query) -> false
      query.period == "realtime" -> false
      true -> requested?
    end
  end

  @spec trace(%__MODULE__{}, [atom()]) :: %__MODULE__{}
  def trace(%__MODULE__{} = query, metrics) do
    filter_keys =
      query.filters
      |> Enum.map(fn {_op, prop, _value} -> prop end)
      |> Enum.sort()
      |> Enum.join(";")

    metrics = metrics |> Enum.sort() |> Enum.join(";")

    Tracer.set_attributes([
      {"plausible.query.interval", query.interval},
      {"plausible.query.period", query.period},
      {"plausible.query.breakdown_property", query.property},
      {"plausible.query.include_imported", query.include_imported},
      {"plausible.query.filter_keys", filter_keys},
      {"plausible.query.metrics", metrics}
    ])

    query
  end
end
