defmodule Plausible.Stats.Interval do
  @moduledoc """
  Collection of functions to work with intervals.

  The interval of a query defines the granularity of the data. You can think of
  it as a `GROUP BY` clause. Possible values are `minute`, `hour`, `date`,
  `week`, and `month`.
  """

  alias Plausible.Stats.Query

  @type t() :: String.t()
  @type(opt() :: {:site, Plausible.Site.t()} | {:from, Date.t()}, {:to, Date.t()})
  @type opts :: list(opt())
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
  """
  def default_for_period(period) do
    case period do
      "realtime" -> "minute"
      "day" -> "hour"
      period when period in ["custom", "7d", "30d", "month"] -> "date"
      period when period in ["6mo", "12mo", "year"] -> "month"
    end
  end

  @spec default_for_date_range(Date.Range.t()) :: t()
  @doc """
  Returns the suggested interval for the given `Date.Range` struct.
  """
  def default_for_date_range(%Date.Range{first: first, last: last}) do
    cond do
      Timex.diff(last, first, :months) > 0 ->
        "month"

      Timex.diff(last, first, :days) > 0 ->
        "date"

      true ->
        "hour"
    end
  end

  @valid_by_period %{
    "realtime" => ["minute"],
    "day" => ["minute", "hour"],
    "7d" => ["hour", "date"],
    "month" => ["date", "week"],
    "30d" => ["date", "week"],
    "6mo" => ["date", "week", "month"],
    "12mo" => ["date", "week", "month"],
    "year" => ["date", "week", "month"],
    "custom" => ["date", "week", "month"],
    "all" => ["date", "week", "month"]
  }

  @spec valid_by_period(opts()) :: map()
  def valid_by_period(opts \\ []) do
    site = Keyword.fetch!(opts, :site)

    table =
      with %Date{} = from <- Keyword.get(opts, :from),
           %Date{} = to <- Keyword.get(opts, :to),
           true <- abs(Timex.diff(from, to, :months)) > 12 do
        Map.replace(@valid_by_period, "custom", ["week", "month"])
      else
        _ ->
          @valid_by_period
      end

    with %Date{} = stats_start <- Plausible.Sites.stats_start_date(site),
         true <- abs(Timex.diff(Date.utc_today(), stats_start, :months)) > 12 do
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

  def format_datetime(%Date{} = date), do: Date.to_string(date)

  def format_datetime(%DateTime{} = datetime),
    do: Timex.format!(datetime, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

  # Realtime graphs return numbers
  def format_datetime(other), do: other

  @doc """
  Returns list of time bucket labels for the given query.
  """
  def time_dimension(query) do
    Enum.find(query.dimensions, &String.starts_with?(&1, "time"))
  end

  def time_labels(query) do
    time_labels_for_dimension(time_dimension(query), query)
  end

  defp time_labels_for_dimension("time:month", query) do
    n_buckets =
      Timex.diff(
        query.date_range.last,
        Date.beginning_of_month(query.date_range.first),
        :months
      )

    Enum.map(n_buckets..0, fn shift ->
      query.date_range.last
      |> Date.beginning_of_month()
      |> Timex.shift(months: -shift)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:week", query) do
    n_buckets =
      Timex.diff(
        query.date_range.last,
        Date.beginning_of_week(query.date_range.first),
        :weeks
      )

    Enum.map(0..n_buckets, fn shift ->
      query.date_range.first
      |> Timex.shift(weeks: shift)
      |> date_or_weekstart(query)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:day", query) do
    query.date_range
    |> Enum.into([])
    |> Enum.map(&format_datetime/1)
  end

  @full_day_in_hours 23
  defp time_labels_for_dimension("time:hour", query) do
    n_buckets =
      if query.date_range.first == query.date_range.last do
        @full_day_in_hours
      else
        end_time =
          query.date_range.last
          |> Timex.to_datetime()
          |> Timex.end_of_day()

        Timex.diff(end_time, query.date_range.first, :hours)
      end

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> Timex.to_datetime()
      |> Timex.shift(hours: step)
      |> DateTime.truncate(:second)
      |> format_datetime()
    end)
  end

  # Only supported in dashboards not via API
  defp time_labels_for_dimension("time:minute", %Query{period: "30m"}) do
    Enum.into(-30..-1, [])
  end

  @full_day_in_minutes 24 * 60 - 1
  defp time_labels_for_dimension("time:minute", query) do
    n_buckets =
      if query.date_range.first == query.date_range.last do
        @full_day_in_minutes
      else
        Timex.diff(query.date_range.last, query.date_range.first, :minutes)
      end

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> Timex.to_datetime()
      |> Timex.shift(minutes: step)
      |> format_datetime()
    end)
  end

  defp date_or_weekstart(date, query) do
    weekstart = Timex.beginning_of_week(date)

    if Enum.member?(query.date_range, weekstart) do
      weekstart
    else
      date
    end
  end
end
