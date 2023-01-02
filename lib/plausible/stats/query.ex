defmodule Plausible.Stats.Query do
  defstruct date_range: nil,
            interval: nil,
            period: nil,
            filters: %{},
            sample_threshold: 20_000_000,
            include_imported: false

  @default_sample_threshold 20_000_000
  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{FilterParser, Interval}

  def shift_back(%__MODULE__{period: "year"} = query, site) do
    # Querying current year to date
    {new_first, new_last} =
      if Timex.compare(Timex.now(site.timezone), query.date_range.first, :year) == 0 do
        diff =
          Timex.diff(
            Timex.beginning_of_year(Timex.now(site.timezone)),
            Timex.now(site.timezone),
            :days
          ) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         Timex.now(site.timezone) |> Timex.to_date() |> Timex.shift(days: diff)}
      else
        diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         query.date_range.last |> Timex.shift(days: diff)}
      end

    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  def shift_back(%__MODULE__{period: "month"} = query, site) do
    # Querying current month to date
    {new_first, new_last} =
      if Timex.compare(Timex.now(site.timezone), query.date_range.first, :month) == 0 do
        diff =
          Timex.diff(
            Timex.beginning_of_month(Timex.now(site.timezone)),
            Timex.now(site.timezone),
            :days
          ) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         Timex.now(site.timezone) |> Timex.to_date() |> Timex.shift(days: diff)}
      else
        diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         query.date_range.last |> Timex.shift(days: diff)}
      end

    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  def shift_back(query, _site) do
    diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1
    new_first = query.date_range.first |> Timex.shift(days: diff)
    new_last = query.date_range.last |> Timex.shift(days: diff)
    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  def from(site, %{"period" => "realtime"} = params) do
    date = today(site.timezone)

    %__MODULE__{
      period: "realtime",
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      date_range: Date.range(date, date),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold),
      include_imported: false
    }
  end

  def from(site, %{"period" => "day"} = params) do
    date = parse_single_date(site.timezone, params)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "7d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -6)

    %__MODULE__{
      period: "7d",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "30d"} = params) do
    end_date = parse_single_date(site.timezone, params)
    start_date = end_date |> Timex.shift(days: -30)

    %__MODULE__{
      period: "30d",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "month"} = params) do
    date = parse_single_date(site.timezone, params)

    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "6mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -5)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "6mo",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "12mo"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -11)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "12mo",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "year"} = params) do
    end_date =
      parse_single_date(site.timezone, params)
      |> Timex.end_of_year()

    start_date = Timex.beginning_of_year(end_date)

    %__MODULE__{
      period: "year",
      date_range: Date.range(start_date, end_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(site, %{"period" => "all"} = params) do
    now = today(site.timezone)
    start_date = Plausible.Site.local_start_date(site) || now

    cond do
      Timex.diff(now, start_date, :months) > 0 ->
        from(
          site,
          Map.merge(params, %{
            "period" => "custom",
            "from" => Date.to_iso8601(start_date),
            "to" => Date.to_iso8601(now),
            "interval" => params["interval"] || "month"
          })
        )
        |> Map.put(:period, "all")

      Timex.diff(now, start_date, :days) > 0 ->
        from(
          site,
          Map.merge(params, %{
            "period" => "custom",
            "from" => Date.to_iso8601(start_date),
            "to" => Date.to_iso8601(now),
            "interval" => params["interval"] || "date"
          })
        )
        |> Map.put(:period, "all")

      true ->
        from(site, Map.merge(params, %{"period" => "day", "date" => "today"}))
        |> Map.put(:period, "all")
    end
  end

  def from(site, %{"period" => "custom", "from" => from, "to" => to} = params) do
    new_params =
      params
      |> Map.delete("from")
      |> Map.delete("to")
      |> Map.put("date", Enum.join([from, to], ","))

    from(site, new_params)
  end

  def from(site, %{"period" => "custom", "date" => date} = params) do
    [from, to] = String.split(date, ",")
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))

    %__MODULE__{
      period: "custom",
      date_range: Date.range(from_date, to_date),
      interval: params["interval"] || Interval.default_for_period(params["period"]),
      filters: FilterParser.parse_filters(params["filters"]),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
  end

  def from(tz, params) do
    __MODULE__.from(tz, Map.merge(params, %{"period" => "30d"}))
  end

  def put_filter(query, key, val) do
    %__MODULE__{
      query
      | filters: Map.put(query.filters, key, val)
    }
  end

  def treat_page_filter_as_entry_page(%__MODULE__{filters: %{"visit:entry_page" => _}} = q), do: q

  def treat_page_filter_as_entry_page(%__MODULE__{filters: %{"event:page" => f}} = q) do
    q
    |> put_filter("visit:entry_page", f)
    |> put_filter("event:page", nil)
  end

  def treat_page_filter_as_entry_page(q), do: q

  def treat_prop_filter_as_entry_prop(%__MODULE__{filters: filters} = q) do
    prop_filter = get_filter_by_prefix(q, "event:props:")

    case {filters["event:goal"], prop_filter} do
      {nil, {"event:props:" <> prop, filter_value}} ->
        q
        |> remove_event_filters([:props])
        |> put_filter("visit:entry_props:" <> prop, filter_value)

      _ ->
        q
    end
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
      _ -> Timex.now(tz) |> Timex.to_date()
    end
  end

  defp maybe_include_imported(query, site, params) do
    imported_data_requested = params["with_imported"] == "true"
    has_imported_data = site.imported_data && site.imported_data.status == "ok"

    date_range_overlaps =
      has_imported_data && !Timex.after?(query.date_range.first, site.imported_data.end_date)

    no_filters_applied = Enum.empty?(query.filters)

    include_imported =
      imported_data_requested && has_imported_data && date_range_overlaps && no_filters_applied

    %{query | include_imported: !!include_imported}
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
