defmodule Plausible.Stats.Query do
  defstruct [date_range: nil, step_type: nil, period: nil]

  def new(attrs) do
    attrs
      |> Enum.into(%{})
      |> Map.put(:__struct__, __MODULE__)
  end

  def from(tz, %{"period" => "day"}) do
    %__MODULE__{
      period: "day",
      date_range: Date.range(today(tz), today(tz)),
      step_type: "hour"
    }
  end

  def from(tz, %{"period" => "week"}) do
    start_date = Timex.shift(today(tz), days: -7)

    %__MODULE__{
      period: "week",
      date_range: Date.range(start_date, today(tz)),
      step_type: "date"
    }
  end

  def from(tz, %{"period" => "month"}) do
    start_date = Timex.shift(today(tz), days: -30)

    %__MODULE__{
      period: "month",
      date_range: Date.range(start_date, today(tz)),
      step_type: "date"
    }
  end

  def from(tz, %{"period" => "3mo"}) do
    start_date = Timex.shift(today(tz), months: -3)

    %__MODULE__{
      period: "3mo",
      date_range: Date.range(start_date, today(tz)),
      step_type: "date"
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
    __MODULE__.from(tz, %{"period" => "month"})
  end

  defp today(tz) do
    Timex.now(tz) |> Timex.to_date
  end
end

