defmodule Plausible.Stats.Query do
  defstruct date_range: nil, step_type: nil, period: nil, steps: nil, filters: %{}

  def shift_back(%__MODULE__{period: "day"} = query) do
    new_date = query.date_range.first |> Timex.shift(days: -1)
    Map.put(query, :date_range, Date.range(new_date, new_date))
  end

  # def shift_back(%__MODULE__{period: "day"} = query, site) do
  #   # IO.inspect(interval)
  #   IO.puts("running day")
  #   diff = Timex.diff(Timex.beginning_of_day(Timex.now(site.timezone)), Timex.now(site.timezone), :minute)
  #   IO.puts(diff)
  #   new_first = Timex.to_datetime(query.date_range.first) |> Timex.shift(minutes: diff)
  #   # IO.puts(Timex.to_date(Timex.now(site.timezone)))
  #   IO.inspect(Timex.now(site.timezone))
  #   IO.inspect(Timex.to_datetime(query.date_range.last |> Timex.shift(days: 1)))
  #   IO.puts(query.date_range.last)
  #   new_last = if Timex.compare(Timex.now(site.timezone), Timex.to_datetime(query.date_range.last |> Timex.shift(days: 1))) >= 0 do
  #     IO.puts("doing +1")
  #     Timex.to_datetime(query.date_range.last) |> Timex.shift(days: 1) |> Timex.shift(minutes: diff)
  #   else
  #     Timex.now(site.timezone) |> Timex.shift(minutes: diff)
  #   end

  #   IO.puts("prev query times")
  #   IO.puts(new_first)
  #   IO.puts(new_last)
  #   interval = Timex.Interval.new(from: new_first, until: new_last)
  #   IO.inspect(interval)

  #   date_range = %{}
  #   date_range = Map.put(date_range, :first, Timex.to_naive_datetime(new_first))
  #   date_range = Map.put(date_range, :last, Timex.to_naive_datetime(new_last))

  #   Map.put(query, :date_range, date_range)
  # end

  def shift_back(%__MODULE__{period: "month"} = query, site) do
    {new_first, new_last} = if Timex.compare(Timex.now(site.timezone), query.date_range.last, :day) <= 0 && Timex.compare(Timex.now(site.timezone), query.date_range.first, :day) >= 0 do # if the current day is within the original query
      diff = Timex.diff(Timex.beginning_of_month(Timex.now(site.timezone)), Timex.now(site.timezone), :days) - 1
      {query.date_range.first |> Timex.shift(days: diff), Timex.now(site.timezone) |> Timex.shift(days: diff)}
    else
      diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1
      {query.date_range.first |> Timex.shift(days: diff), query.date_range.last |> Timex.shift(days: diff)}
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
      step_type: "minute",
      date_range: Date.range(date, date),
      filters: parse_filters(params)
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
    else
      %{}
    end
  end
end
