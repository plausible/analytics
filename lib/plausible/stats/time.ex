defmodule Plausible.Stats.Time do
  @moduledoc """
  Collection of functions to work with time in queries.
  """

  alias Plausible.Stats.{Query, DateTimeRange}

  def utc_boundaries(%Query{date_range: date_range}, site) do
    %DateTimeRange{first: first, last: last} = date_range

    first =
      first
      |> DateTime.shift_zone!("Etc/UTC")
      |> DateTime.to_naive()
      |> beginning_of_time(site.native_stats_start_at)

    last = DateTime.shift_zone!(last, "Etc/UTC") |> DateTime.to_naive()

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
    date_range = DateTimeRange.to_date_range(query.date_range)

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
    date_range = DateTimeRange.to_date_range(query.date_range)

    n_buckets =
      Timex.diff(
        date_range.last,
        Date.beginning_of_week(date_range.first),
        :weeks
      )

    Enum.map(0..n_buckets, fn shift ->
      date_range.first
      |> Date.shift(week: shift)
      |> date_or_weekstart(query)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:day", query) do
    query.date_range
    |> DateTimeRange.to_date_range()
    |> Enum.into([])
    |> Enum.map(&format_datetime/1)
  end

  defp time_labels_for_dimension("time:hour", query) do
    n_buckets = DateTime.diff(query.date_range.last, query.date_range.first, :hour)

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> DateTime.to_naive()
      |> NaiveDateTime.shift(hour: step)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:minute", query) do
    n_buckets = DateTime.diff(query.date_range.last, query.date_range.first, :minute) - 1

    first_datetime =
      query.date_range.first
      |> DateTime.to_naive()
      |> Map.put(:second, 0)

    Enum.map(0..n_buckets, fn step ->
      first_datetime
      |> NaiveDateTime.shift(minute: step)
      |> format_datetime()
    end)
  end

  def date_or_weekstart(date, query) do
    weekstart = Date.beginning_of_week(date)

    date_range = DateTimeRange.to_date_range(query.date_range)

    if Enum.member?(date_range, weekstart) do
      weekstart
    else
      date
    end
  end
end
