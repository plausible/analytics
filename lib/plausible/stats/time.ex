defmodule Plausible.Stats.Time do
  @moduledoc """
  Collection of functions to work with time in queries.
  """

  alias Plausible.Stats.{Query, DateTimeRange}

  def utc_boundaries(%Query{utc_time_range: time_range}, site) do
    first =
      time_range.first
      |> DateTime.to_naive()
      |> beginning_of_time(site.native_stats_start_at)

    last = DateTime.to_naive(time_range.last)

    {first, last}
  end

  defp beginning_of_time(candidate, native_stats_start_at) do
    if Timex.after?(native_stats_start_at, candidate) do
      native_stats_start_at
    else
      candidate
    end
  end

  def format_datetime(%Date{} = date), do: Date.to_string(date)

  def format_datetime(%mod{} = datetime) when mod in [NaiveDateTime, DateTime],
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")

  # Realtime graphs return numbers
  def format_datetime(other), do: other

  def time_dimension(query) do
    Enum.find(query.dimensions, &time_dimension?/1)
  end

  def time_dimension?("time" <> _rest), do: true
  def time_dimension?(_dimension), do: false

  @doc """
  Returns list of time bucket labels for the given query.
  """
  def time_labels(query) do
    time_labels_for_dimension(time_dimension(query), query)
  end

  defp time_labels_for_dimension("time:month", query) do
    date_range = Query.date_range(query)

    n_buckets =
      Timex.diff(
        date_range.last,
        Date.beginning_of_month(date_range.first),
        :months
      )

    Enum.map(n_buckets..0, fn shift ->
      date_range.last
      |> Date.beginning_of_month()
      |> Date.shift(month: -shift)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:week", query) do
    date_range = Query.date_range(query)

    n_buckets =
      Timex.diff(
        date_range.last,
        Date.beginning_of_week(date_range.first),
        :weeks
      )

    Enum.map(0..n_buckets, fn shift ->
      date_range.first
      |> Date.shift(week: shift)
      |> date_or_weekstart(date_range)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:day", query) do
    Query.date_range(query)
    |> Enum.into([])
    |> Enum.map(&format_datetime/1)
  end

  defp time_labels_for_dimension("time:hour", query) do
    time_range = query.utc_time_range |> DateTimeRange.to_timezone(query.timezone)

    from_timestamp = time_range.first |> Map.merge(%{minute: 0, second: 0})
    n_buckets = DateTime.diff(time_range.last, from_timestamp, :hour)

    Enum.map(0..n_buckets, fn step ->
      from_timestamp
      |> DateTime.to_naive()
      |> NaiveDateTime.shift(hour: step)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:minute", query) do
    time_range = query.utc_time_range |> DateTimeRange.to_timezone(query.timezone)
    first_datetime = Map.put(time_range.first, :second, 0)

    first_datetime
    |> Stream.iterate(fn datetime -> DateTime.shift(datetime, minute: 1) end)
    |> Enum.take_while(fn datetime ->
      current_minute = Map.put(query.now, :second, 0)

      DateTime.before?(datetime, time_range.last) &&
        DateTime.before?(datetime, current_minute)
    end)
    |> Enum.map(&format_datetime/1)
  end

  def date_or_weekstart(date, date_range) do
    weekstart = Date.beginning_of_week(date)

    if Enum.member?(date_range, weekstart) do
      weekstart
    else
      date
    end
  end
end
