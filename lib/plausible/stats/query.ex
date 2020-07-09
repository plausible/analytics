defmodule Plausible.Stats.Query do
  defstruct date_range: nil, step_type: nil, period: nil, steps: nil, filters: %{}

  def shift_back(%__MODULE__{period: "day"} = query) do
    new_date = query.date_range.first |> Timex.shift(days: -1)
    Map.put(query, :date_range, Date.range(new_date, new_date))
  end

  def shift_back(query) do
    diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1
    new_first = query.date_range.first |> Timex.shift(days: diff)
    new_last = query.date_range.last |> Timex.shift(days: diff)
    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  def from(tz, %{"period" => "realtime"} = params) do
    date = today(tz)

    %__MODULE__{
      period: "realtime",
      date_range: Date.range(date, date)
    }
  end

  def from(_tz, %{"period" => "day", "date" => date} = params) do
    date = Date.from_iso8601!(date)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      step_type: "hour",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "day"} = params) do
    date = today(tz)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      step_type: "hour",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "7d"} = params) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -7)

    %__MODULE__{
      period: "7d",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "30d"} = params) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -30)

    %__MODULE__{
      period: "30d",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "60d"} = params) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -60)

    %__MODULE__{
      period: "60d",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      filters: parse_filters(params)
    }
  end

  def from(_tz, %{"period" => "month", "date" => date} = params) do
    start_date = Date.from_iso8601!(date) |> Timex.beginning_of_month()
    end_date = Timex.end_of_month(start_date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      steps: Timex.diff(start_date, end_date, :days),
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "6mo"} = params) do
    start_date =
      Timex.shift(today(tz), months: -5)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "6mo",
      date_range: Date.range(start_date, today(tz)),
      step_type: "month",
      steps: 6,
      filters: parse_filters(params)
    }
  end

  def from(tz, %{"period" => "12mo"} = params) do
    start_date =
      Timex.shift(today(tz), months: -11)
      |> Timex.beginning_of_month()

    %__MODULE__{
      period: "12mo",
      date_range: Date.range(start_date, today(tz)),
      step_type: "month",
      steps: 12,
      filters: parse_filters(params)
    }
  end

  def from(_tz, %{"period" => "custom", "from" => from, "to" => to} = params) do
    from_date = Date.from_iso8601!(from)
    to_date = Date.from_iso8601!(to)

    %__MODULE__{
      period: "custom",
      date_range: Date.range(from_date, to_date),
      step_type: "date",
      filters: parse_filters(params)
    }
  end

  def from(tz, _) do
    __MODULE__.from(tz, %{"period" => "30d"})
  end

  defp today(tz) do
    Timex.now(tz) |> Timex.to_date()
  end

  defp parse_filters(params) do
    if params["filters"] do
      Jason.decode!(params["filters"])
    end
  end
end
