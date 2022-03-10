defmodule Plausible.Stats.Query do
  defstruct date_range: nil,
            interval: nil,
            period: nil,
            filters: %{},
            sample_threshold: 20_000_000,
            include_imported: false

  @default_sample_threshold 20_000_000

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
      interval: "minute",
      date_range: Date.range(date, date),
      filters: parse_filters(params),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold),
      include_imported: false
    }
  end

  def from(site, %{"period" => "day"} = params) do
    date = parse_single_date(site.timezone, params)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      interval: "hour",
      filters: parse_filters(params),
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
      interval: "date",
      filters: parse_filters(params),
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
      interval: "date",
      filters: parse_filters(params),
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
      interval: "date",
      filters: parse_filters(params),
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
      interval: Map.get(params, "interval", "month"),
      filters: parse_filters(params),
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
      interval: Map.get(params, "interval", "month"),
      filters: parse_filters(params),
      sample_threshold: Map.get(params, "sample_threshold", @default_sample_threshold)
    }
    |> maybe_include_imported(site, params)
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
      interval: Map.get(params, "interval", "date"),
      filters: parse_filters(params),
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

  def remove_goal(query) do
    props =
      Enum.map(query.filters, fn {key, _val} -> key end)
      |> Enum.filter(fn filter_key -> String.starts_with?(filter_key, "event:props:") end)

    new_filters =
      query.filters
      |> Map.drop(props)
      |> Map.delete("event:goal")

    %__MODULE__{query | filters: new_filters}
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

  defp parse_filters(%{"filters" => filters}) when is_binary(filters) do
    case Jason.decode(filters) do
      {:ok, parsed} -> parsed
      {:error, err} -> parse_filter_expression(err.data)
    end
  end

  defp parse_filters(%{"filters" => filters}) when is_map(filters), do: filters
  defp parse_filters(_), do: %{}

  defp parse_filter_expression(str) do
    filters = String.split(str, ";")

    Enum.map(filters, &parse_single_filter/1)
    |> Enum.into(%{})
  end

  defp parse_single_filter(str) do
    [key, val] =
      String.trim(str)
      |> String.split(["==", "!="], trim: true)
      |> Enum.map(&String.trim/1)

    is_negated = String.contains?(str, "!=")
    is_list = String.contains?(val, "|")
    is_wildcard = String.contains?(val, "*")

    cond do
      key == "event:goal" -> {key, parse_goal_filter(val)}
      is_wildcard && is_negated -> {key, {:does_not_match, val}}
      is_wildcard -> {key, {:matches, val}}
      is_list -> {key, {:member, String.split(val, "|")}}
      is_negated -> {key, {:is_not, val}}
      true -> {key, {:is, val}}
    end
  end

  defp parse_goal_filter("Visit " <> page), do: {:is, :page, page}
  defp parse_goal_filter(event), do: {:is, :event, event}

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
end
