defmodule Plausible.Stats.Time do
  @moduledoc """
  Collection of functions to work with time in queries.
  """

  alias Plausible.Stats.{Query, DateTimeRange}

  def utc_boundaries(%Query{
        utc_time_range: time_range,
        site_native_stats_start_at: native_stats_start_at
      }) do
    first =
      time_range.first
      |> DateTime.to_naive()
      |> beginning_of_time(native_stats_start_at)

    last = DateTime.to_naive(time_range.last)

    {first, last}
  end

  defp beginning_of_time(candidate, native_stats_start_at) do
    if NaiveDateTime.after?(native_stats_start_at, candidate) do
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
    date_range = Query.date_range(query, trim_trailing: should_trim_future_dates?(query))

    n_buckets =
      Timex.diff(
        date_range.last,
        Date.beginning_of_month(date_range.first),
        :months
      )

    Enum.map(n_buckets..0//-1, fn shift ->
      date_range.last
      |> Date.beginning_of_month()
      |> Date.shift(month: -shift)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:week", query) do
    date_range = Query.date_range(query, trim_trailing: should_trim_future_dates?(query))

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
    query
    |> Query.date_range(trim_trailing: should_trim_future_dates?(query))
    |> Enum.into([])
    |> Enum.map(&format_datetime/1)
  end

  defp time_labels_for_dimension("time:hour", query) do
    time_range = query.utc_time_range |> DateTimeRange.to_timezone(query.timezone)

    from_timestamp = time_range.first |> Map.merge(%{minute: 0, second: 0})
    to_timestamp = time_range.last

    to_timestamp =
      if should_trim_future_dates?(query) do
        current_hour =
          query.now |> DateTime.shift_zone!(query.timezone) |> Map.merge(%{minute: 0, second: 0})

        Enum.min([to_timestamp, current_hour], DateTime)
      else
        to_timestamp
      end

    n_buckets = DateTime.diff(to_timestamp, from_timestamp, :hour)

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

      DateTime.before?(datetime, time_range.last) and
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

  defp should_trim_future_dates?(%Query{period: "month"} = query) do
    today =
      query.now
      |> DateTime.shift_zone!(query.timezone)
      |> DateTime.to_date()

    date_range = Query.date_range(query)

    current_month_start = Date.beginning_of_month(today)
    current_month_end = Date.end_of_month(today)

    date_range.first == current_month_start and date_range.last == current_month_end
  end

  defp should_trim_future_dates?(%Query{period: "year"} = query) do
    today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()
    date_range = Query.date_range(query)

    current_year_start = Date.new!(today.year, 1, 1)
    current_year_end = Date.new!(today.year, 12, 31)

    date_range.first == current_year_start and date_range.last == current_year_end
  end

  defp should_trim_future_dates?(%Query{period: "day"} = query) do
    today = query.now |> DateTime.shift_zone!(query.timezone) |> DateTime.to_date()
    date_range = Query.date_range(query)
    date_range.first == today and date_range.last == today
  end

  defp should_trim_future_dates?(_query), do: false
end
