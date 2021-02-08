defmodule Plausible.Stats.Query do
  defstruct date_range: nil, interval: nil, period: nil, filters: %{}

  def shift_back(%__MODULE__{period: "day"} = query) do
    new_date = query.date_range.first |> Timex.shift(days: -1)
    Map.put(query, :date_range, Date.range(new_date, new_date))
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

  def from(tz, %{"period" => "realtime"} = params) do
    date = today(tz)

    %__MODULE__{
      period: "realtime",
      interval: "minute",
      date_range: Date.range(date, date),
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "day"} = params) do
    date =
      if params["date"] do
        Date.from_iso8601!(params["date"])
      else
        today(tz)
      end

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      interval: "hour",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "7d"} = params) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -7)

    %__MODULE__{
      period: "7d",
      date_range: Date.range(start_date, end_date),
      interval: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "30d"} = params) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -30)

    %__MODULE__{
      period: "30d",
      date_range: Date.range(start_date, end_date),
      interval: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "month"} = params) do
    date =
      if params["date"] do
        Date.from_iso8601!(params["date"])
      else
        today(tz)
      end

    start_date = Timex.beginning_of_month(date)
    end_date = Timex.end_of_month(date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date),
      interval: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "6mo"} = params) do
    end_date =
      case params["date"] do
        nil -> today(tz)
        date -> Date.from_iso8601!(date)
      end
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -5)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "6mo",
      date_range: Date.range(start_date, end_date),
      interval: Map.get(params, "interval", "month"),
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "12mo"} = params) do
    end_date =
      case params["date"] do
        nil -> today(tz)
        date -> Date.from_iso8601!(date)
      end
      |> Timex.end_of_month()

    start_date =
      Timex.shift(end_date, months: -11)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "12mo",
      date_range: Date.range(start_date, end_date),
      interval: Map.get(params, "interval", "month"),
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "custom", "from" => from, "to" => to} = params) do
    new_params =
      params
      |> Map.delete("from")
      |> Map.delete("to")
      |> Map.put("date", Enum.join([from, to], ","))

    from(tz, new_params)
  end

  def from(_tz, %{"period" => "custom", "date" => date} = params) do
    [from, to] = String.split(date, ",")
    from_date = Date.from_iso8601!(from)
    to_date = Date.from_iso8601!(to)

    %__MODULE__{
      period: "custom",
      date_range: Date.range(from_date, to_date),
      interval: Map.get(params, "interval", "date"),
      filters: parse_filters(params)
    }
  end

  def from(tz, _) do
    __MODULE__.from(tz, %{"period" => "30d"})
  end

  defp today(tz) do
    Timex.now(tz) |> Timex.to_date()
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
    String.trim(str)
    |> String.split("==")
    |> Enum.map(&String.trim/1)
    |> List.to_tuple()
  end
end
