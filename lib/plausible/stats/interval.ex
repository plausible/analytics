defmodule Plausible.Stats.Interval do
  @moduledoc """
  Collection of functions to work with intervals.

  The interval of a query defines the granularity of the data. You can think of
  it as a `GROUP BY` clause. Possible values are `minute`, `hour`, `date`,
  `week`, and `month`.
  """

  @type t() :: String.t()
  @typep period() :: String.t()

  @intervals ~w(minute hour date week month)

  @spec valid?(t()) :: boolean()
  def valid?(interval) do
    interval in @intervals
  end

  @spec default_for_period(period()) :: t()
  @doc """
  Returns the suggested interval for the given time period.

  ## Examples

    iex> Plausible.Stats.Interval.default_for_period("7d")
    "date"

  """
  def default_for_period(period) do
    case period do
      "realtime" -> "minute"
      "day" -> "hour"
      period when period in ["custom", "7d", "30d", "month"] -> "date"
      period when period in ["6mo", "12mo", "year"] -> "month"
    end
  end
end
