defmodule Plausible.Stats.Time do
  @moduledoc """
  Collection of functions to work with time in queries.
  """

  alias Plausible.Stats.Query
  alias Plausible.Timezones

  def utc_boundaries(%Query{date_range: date_range, now: now}, site)
      when date_range in ["realtime", "30m"] do
    realtime_utc_boundaries(site, now, date_range)
  end

  def utc_boundaries(%Query{date_range: date_range}, site) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      first
      |> Timezones.to_utc_datetime(site.timezone)
      |> beginning_of_time(site.native_stats_start_at)

    {:ok, last} = NaiveDateTime.new(date_range.last |> Date.shift(day: 1), ~T[00:00:00])

    last_datetime = Timezones.to_utc_datetime(last, site.timezone)

    {first_datetime, last_datetime}
  end

  def date_or_weekstart(date, query) do
    weekstart = Timex.beginning_of_week(date)
    date_range = Date.range(query.date_range.first, query.date_range.last)

    if Enum.member?(date_range, weekstart) do
      weekstart
    else
      date
    end
  end

  defp realtime_utc_boundaries(site, now, period) do
    duration_minutes =
      case period do
        "realtime" -> 5
        "30m" -> 30
      end

    last_datetime =
      now
      |> NaiveDateTime.shift(second: 5)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      now
      |> NaiveDateTime.shift(minute: -duration_minutes)
      |> NaiveDateTime.truncate(:second)
      |> beginning_of_time(site.native_stats_start_at)

    {first_datetime, last_datetime}
  end

  defp beginning_of_time(candidate, native_stats_start_at) do
    if Timex.after?(native_stats_start_at, candidate) do
      native_stats_start_at
    else
      candidate
    end
  end

  def format_datetime(%Date{} = date), do: Date.to_string(date)

  def format_datetime(%DateTime{} = datetime),
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
    n_buckets =
      Timex.diff(
        query.date_range.last,
        Date.beginning_of_month(query.date_range.first),
        :months
      )

    Enum.map(n_buckets..0, fn shift ->
      query.date_range.last
      |> Date.beginning_of_month()
      |> Date.shift(month: -shift)
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
      |> Date.shift(week: shift)
      |> date_or_weekstart(query)
      |> format_datetime()
    end)
  end

  defp time_labels_for_dimension("time:day", query) do
    Date.range(query.date_range.first, query.date_range.last)
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
      |> DateTime.shift(hour: step)
      |> DateTime.truncate(:second)
      |> format_datetime()
    end)
  end

  # Only supported in dashboards not via API
  defp time_labels_for_dimension("time:minute", %Query{date_range: "30m"}) do
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
      |> DateTime.shift(minute: step)
      |> format_datetime()
    end)
  end
end
