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
    date_range = Query.date_range(query)

    n_buckets =
      Plausible.Times.diff(
        date_range.last,
        Date.beginning_of_month(date_range.first),
        :month
      )

    Enum.map(n_buckets..0//-1, fn shift ->
      date_range.last
      |> Date.beginning_of_month()
      |> Date.shift(month: -shift)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:week", query) do
    date_range = Query.date_range(query)

    n_buckets =
      Plausible.Times.diff(
        date_range.last,
        Date.beginning_of_week(date_range.first),
        :week
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

  def partial_time_labels(time_labels, query) do
    time_dimension = time_dimension(query)

    range_start = to_naive_in_tz!(query.utc_time_range.first, query.timezone)
    range_end = to_naive_in_tz!(query.utc_time_range.last, query.timezone)
    now = to_naive_in_tz!(query.now, query.timezone)

    cutoff = if NaiveDateTime.before?(now, range_end), do: now, else: range_end

    first_bucket = List.first(time_labels)
    last_bucket = List.last(time_labels)

    first_partial? =
      case bucket_start(first_bucket, time_dimension) do
        nil -> false
        start -> NaiveDateTime.after?(range_start, start)
      end

    last_partial? =
      case bucket_end(last_bucket, time_dimension) do
        nil -> false
        bucket_end -> NaiveDateTime.after?(bucket_end, cutoff)
      end

    [
      if(first_partial?, do: first_bucket),
      if(last_partial?, do: last_bucket)
    ]
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp bucket_start(label, "time:week") do
    case Date.from_iso8601(label) do
      {:ok, date} -> NaiveDateTime.new!(Date.beginning_of_week(date), ~T[00:00:00])
      _ -> nil
    end
  end

  defp bucket_start(label, _time_dimension) do
    case Date.from_iso8601(label) do
      {:ok, date} ->
        NaiveDateTime.new!(date, ~T[00:00:00])

      _ ->
        case NaiveDateTime.from_iso8601(label) do
          {:ok, naive_datetime} -> naive_datetime
          _ -> nil
        end
    end
  end

  defp bucket_end(label, time_dimension) do
    shift_unit =
      case time_dimension do
        "time:month" -> :month
        "time:week" -> :week
        "time:day" -> :day
        "time:hour" -> :hour
        "time:minute" -> :minute
      end

    case bucket_start(label, time_dimension) do
      nil -> nil
      start -> NaiveDateTime.shift(start, [{shift_unit, 1}, {:second, -1}])
    end
  end

  defp to_naive_in_tz!(utc_datetime, timezone) do
    utc_datetime
    |> DateTime.shift_zone!(timezone)
    |> DateTime.to_naive()
  end

  def present_index(time_labels, query) do
    now = DateTime.shift_zone!(query.now, query.timezone)

    current_label =
      case time_dimension(query) do
        "time:month" ->
          DateTime.to_date(now)
          |> Date.beginning_of_month()
          |> Date.to_string()

        "time:week" ->
          DateTime.to_date(now)
          |> date_or_weekstart(Query.date_range(query))
          |> Date.to_string()

        "time:day" ->
          DateTime.to_date(now)
          |> Date.to_string()

        "time:hour" ->
          Calendar.strftime(now, "%Y-%m-%d %H:00:00")

        "time:minute" ->
          Calendar.strftime(now, "%Y-%m-%d %H:%M:00")
      end

    Enum.find_index(time_labels, &(&1 == current_label))
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
