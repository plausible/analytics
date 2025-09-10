defmodule Plausible.Stats.Interval do
  @moduledoc """
  Collection of functions to work with intervals.

  The interval of a query defines the granularity of the data. You can think of
  it as a `GROUP BY` clause. Possible values are `minute`, `hour`, `day`,
  `week`, and `month`.
  """

  alias Plausible.Stats.DateTimeRange

  @type t() :: String.t()
  @type(opt() :: {:site, Plausible.Site.t()} | {:from, Date.t()}, {:to, Date.t()})
  @type opts :: list(opt())
  @typep period() :: String.t()

  @intervals ~w(minute hour day week month)
  @spec list() :: [t()]
  def list, do: @intervals

  @spec valid?(term()) :: boolean()
  def valid?(interval) do
    interval in @intervals
  end

  @spec default_for_period(period()) :: t()
  @doc """
  Returns the suggested interval for the given time period.
  """
  def default_for_period(period) do
    case period do
      period when period in ["realtime", "30m"] -> "minute"
      "day" -> "hour"
      period when period in ["custom", "7d", "28d", "30d", "91d", "month"] -> "day"
      period when period in ["6mo", "12mo", "year"] -> "month"
    end
  end

  @spec default_for_date_range(DateTimeRange.t()) :: t()
  @doc """
  Returns the suggested interval for the given `DateTimeRange` struct.
  """
  def default_for_date_range(%DateTimeRange{first: first, last: last}) do
    cond do
      Plausible.Times.diff(last, first, :month) > 0 ->
        "month"

      DateTime.diff(last, first, :day) > 0 ->
        "day"

      true ->
        "hour"
    end
  end

  @valid_by_period %{
    "realtime" => ["minute"],
    "day" => ["minute", "hour"],
    "7d" => ["hour", "day"],
    "28d" => ["day", "week"],
    "30d" => ["day", "week"],
    "91d" => ["day", "week", "month"],
    "month" => ["day", "week"],
    "6mo" => ["day", "week", "month"],
    "12mo" => ["day", "week", "month"],
    "year" => ["day", "week", "month"],
    "custom" => ["day", "week", "month"],
    "all" => ["day", "week", "month"]
  }

  @spec valid_by_period(opts()) :: map()
  def valid_by_period(opts \\ []) do
    site = Keyword.fetch!(opts, :site)

    table =
      with %Date{} = from <- Keyword.get(opts, :from),
           %Date{} = to <- Keyword.get(opts, :to),
           true <- abs(Plausible.Times.diff(from, to, :month)) > 12 do
        Map.replace(@valid_by_period, "custom", ["week", "month"])
      else
        _ ->
          @valid_by_period
      end

    with %Date{} = stats_start <- Plausible.Sites.stats_start_date(site),
         true <- abs(Plausible.Times.diff(Date.utc_today(), stats_start, :month)) > 12 do
      Map.replace(table, "all", ["week", "month"])
    else
      _ ->
        table
    end
  end

  @spec valid_for_period?(period(), t(), opts()) :: boolean()
  @doc """
  Returns whether the given interval is valid for a time period.

  Intervals longer than periods are not supported, e.g. current month stats with
  a month interval, or today stats with a week interval.

  There are two dynamic states:
  * `custom` period is only applicable with `month` or `week` intervals,
     if the `opts[:from]` and `opts[:to]` range difference exceeds 12 months
  * `all` period's interval options depend on particular site's `stats_start_date`
    - daily interval is excluded if the all-time range exceeds 12 months
  """
  def valid_for_period?(period, interval, opts \\ []) do
    interval in Map.get(valid_by_period(opts), period, [])
  end
end
