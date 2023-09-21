defmodule Plausible.Stats.Query do
  defstruct date_range: nil,
            interval: nil,
            period: nil,
            filters: %{},
            sample_threshold: 20_000_000,
            imported_data_requested: false,
            include_imported: false

  @default_sample_threshold 20_000_000
  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{FilterParser, Interval}

  @type t :: %__MODULE__{}

  def from(site, params) do
    query_by_period(site, params)
    |> put_interval(params)
    |> put_parsed_filters(params)
    |> put_imported_opts(site, params)
    |> put_sample_threshold(params)
  end

  defp query_by_period(site, %{"period" => "realtime"}) do
    date = today(site.timezone)

    %__MODULE__{
      period: "realtime",
      date_range: Date.range(date, date)
    }
  end

  defp query_by_period(site, %{"period" => "day"} = params) do
    date = parse_single_date(site.timezone, params)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date)
    }
  end

  defp query_by_period(site, %{"period" => "7d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -6)

    %__MODULE__{
      period: "7d",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "30d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -30)

    %__MODULE__{
      period: "30d",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "month"} = params) do
    date = parse_single_date(site.timezone, params)

    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "6mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -5)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "6mo",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "12mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -11)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "12mo",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "year"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_year()

    start_date = Timex.beginning_of_year(end_date)

    %__MODULE__{
      period: "year",
      date_range: Date.range(start_date, end_date)
    }
  end

  defp query_by_period(site, %{"period" => "all"}) do
    now = today(site.timezone)
    start_date = Plausible.Site.local_start_date(site) || now

    %__MODULE__{
      period: "all",
      date_range: Date.range(start_date, now)
    }
  end

  defp query_by_period(site, %{"period" => "custom", "from" => from, "to" => to} = params) do
    new_params =
      params
      |> Map.drop(["from", "to"])
      |> Map.put("date", Enum.join([from, to], ","))

    query_by_period(site, new_params)
  end

  defp query_by_period(_site, %{"period" => "custom", "date" => date}) do
    [from, to] = String.split(date, ",")
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))

    %__MODULE__{
      period: "custom",
      date_range: Date.range(from_date, to_date)
    }
  end

  defp query_by_period(site, params) do
    query_by_period(site, Map.merge(params, %{"period" => "30d"}))
  end

  defp put_interval(%{:period => "all"} = query, params) do
    interval = Map.get(params, "interval", Interval.default_for_date_range(query.date_range))
    Map.put(query, :interval, interval)
  end

  defp put_interval(query, params) do
    interval = Map.get(params, "interval", Interval.default_for_period(query.period))
    Map.put(query, :interval, interval)
  end

  defp put_parsed_filters(query, params) do
    Map.put(query, :filters, FilterParser.parse_filters(params["filters"]))
  end

  defp put_sample_threshold(query, params) do
    sample_threshold =
      case params["sample_threshold"] do
        nil -> @default_sample_threshold
        "infinite" -> :infinite
        value -> String.to_integer(value)
      end

    Map.put(query, :sample_threshold, sample_threshold)
  end

  def put_filter(query, key, val) do
    %__MODULE__{
      query
      | filters: Map.put(query.filters, key, val)
    }
  end

  def remove_event_filters(query, opts) do
    new_filters =
      Enum.filter(query.filters, fn {filter_key, _} ->
        cond do
          :page in opts && filter_key == "event:page" -> false
          :goal in opts && filter_key == "event:goal" -> false
          :props in opts && filter_key && String.starts_with?(filter_key, "event:props:") -> false
          true -> true
        end
      end)
      |> Enum.into(%{})

    %__MODULE__{query | filters: new_filters}
  end

  def has_event_filters?(query) do
    Enum.any?(query.filters, fn
      {"event:" <> _, _} -> true
      _ -> false
    end)
  end

  def get_filter_by_prefix(query, prefix) do
    Enum.find(query.filters, fn {prop, _value} ->
      String.starts_with?(prop, prefix)
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

    query
    |> Map.put(:imported_data_requested, requested?)
    |> Map.put(:include_imported, include_imported?(query, site, requested?))
  end

  @spec include_imported?(t(), Plausible.Site.t(), boolean()) :: boolean()
  def include_imported?(query, site, requested?) do
    cond do
      is_nil(site.imported_data) -> false
      site.imported_data.status != "ok" -> false
      Timex.after?(query.date_range.first, site.imported_data.end_date) -> false
      Enum.any?(query.filters) -> false
      query.period == "realtime" -> false
      true -> requested?
    end
  end

  @spec trace(%__MODULE__{}) :: %__MODULE__{}
  def trace(%__MODULE__{} = query) do
    Tracer.set_attributes([
      {"plausible.query.interval", query.interval},
      {"plausible.query.period", query.period},
      {"plausible.query.include_imported", query.include_imported}
    ])

    query
  end
end
