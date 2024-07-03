defmodule Plausible.Stats.Time do
  @moduledoc """
  Collection of functions to work with time in queries.
  """

  alias Plausible.Stats.Query
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
