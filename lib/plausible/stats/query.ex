defmodule Plausible.Stats.Query do
  defstruct [date_range: nil, step_type: nil, period: nil, steps: nil]

  def new(attrs) do
    attrs
      |> Enum.into(%{})
      |> Map.put(:__struct__, __MODULE__)
  end

  def month(date) do
    %__MODULE__{
      date_range: Date.range(Timex.beginning_of_month(date), Timex.end_of_month(date))
    }
  end

  def day(date) do
    %__MODULE__{
      date_range: Date.range(date, date)
    }
  end

  def shift_back(%__MODULE__{period: "day"} = query) do
    new_date = query.date_range.first |> Timex.shift(days: -1)
    Map.put(query, :date_range, Date.range(new_date, new_date))
  end

  def shift_back(query) do
    diff = Timex.diff(query.date_range.first, query.date_range.last, :days)
    new_first = query.date_range.first |> Timex.shift(days: diff)
    new_last = query.date_range.last |> Timex.shift(days: diff)
    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  def from(_tz, %{"period" => "day", "date" => date}) do
    date = Date.from_iso8601!(date)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      step_type: "hour"
    }
  end

  def from(tz, %{"period" => "day"}) do
    date = today(tz)

    %__MODULE__{
      period: "day",
      date_range: Date.range(date, date),
      step_type: "hour"
    }
  end

  def from(tz, %{"period" => "7d"}) do
    end_date = today(tz)
    start_date = end_date |> Timex.shift(days: -7)

    %__MODULE__{
      period: "7d",
      date_range: Date.range(start_date, end_date),
      step_type: "date"
    }
  end

  def from(_tz, %{"period" => "month", "date" => month_start}) do
    start_date = Date.from_iso8601!(month_start) |> Timex.beginning_of_month
    end_date = Timex.end_of_month(start_date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      steps: Timex.diff(start_date, end_date, :days)
    }
  end

  def from(tz, %{"period" => "month"}) do
    start_date = today(tz) |> Timex.beginning_of_month
    end_date = Timex.end_of_month(start_date)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, end_date),
      step_type: "date",
      steps: Timex.diff(start_date, end_date, :days)
    }
  end

  def from(tz, %{"period" => "3mo"}) do
    start_date = Timex.shift(today(tz), months: -2)
                 |> Timex.beginning_of_month()

    %__MODULE__{
      period: "3mo",
      date_range: Date.range(start_date, today(tz)),
      step_type: "month",
      steps: 3
    }
  end

  def from(tz, %{"period" => "6mo"}) do
    start_date = Timex.shift(today(tz), months: -5)
                 |> Timex.beginning_of_month()

    %__MODULE__{
      period: "6mo",
      date_range: Date.range(start_date, today(tz)),
      step_type: "month",
      steps: 6
    }
  end

  def from(_tz, %{"period" => "custom", "from" => from, "to" => to}) do
    start_date = Date.from_iso8601!(from)
    end_date = Date.from_iso8601!(to)
    date_range = Date.range(start_date, end_date)

    %__MODULE__{
      period: "custom",
      date_range: date_range,
      step_type: "date"
    }
  end

  def from(tz, _) do
    __MODULE__.from(tz, %{"period" => "6mo"})
  end

  defp today(tz) do
    Timex.now(tz) |> Timex.to_date
  end
end

