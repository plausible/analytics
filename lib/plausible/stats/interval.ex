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
  @spec list() :: [t()]
  def list, do: @intervals

  @spec valid?(term()) :: boolean()
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

  @allowed_intervals_for_period %{
    "realtime" => ["minute"],
    "day" => ["minute", "hour"],
    "7d" => ["minute", "hour", "date"],
    "month" => ["minute", "hour", "date", "week"],
    "30d" => ["minute", "hour", "date", "week"],
    "6mo" => ["minute", "hour", "date", "week", "month"],
    "12mo" => ["minute", "hour", "date", "week", "month"],
    "year" => ["minute", "hour", "date", "week", "month"],
    "custom" => ["minute", "hour", "date", "week", "month"],
    "all" => ["minute", "hour", "date", "week", "month"]
  }

  @spec allowed_for_period?(period(), t()) :: boolean()
  @doc """
  Returns whether the given interval is valid for a time period.

  Intervals longer than periods are not supported, e.g. current month stats with
  a month interval, or today stats with a week interval.

  ## Examples


    iex> Plausible.Stats.Interval.allowed_for_period?("month", "date")
    true

    iex> Plausible.Stats.Interval.allowed_for_period?("30d", "month")
    false

    iex> Plausible.Stats.Interval.allowed_for_period?("realtime", "week")
    false

  """
  def allowed_for_period?(period, interval) do
    allowed = Map.get(@allowed_intervals_for_period, period, [])
    interval in allowed
  end
end
