defmodule Plausible.Stats.Comparisons do
  @moduledoc """
  This module provides functions for comparing query periods.

  It allows you to compare a given period with a previous period or with the
  same period from the previous year. For example, you can compare this month's
  main graph with last month or with the same month from last year.
  """

  alias Plausible.Stats
  alias Plausible.Stats.{Query, DateTimeRange, Time}

  @spec get_comparison_utc_time_range(Stats.Query.t()) :: DateTimeRange.t()
  @doc """
  Generates a `DateTimeRange` representing the comparison period of a given
  `%Query{}` struct (i.e. the `source_query`).

  There are different modes and options that determine the outcome of the
  resulting DateTimeRange. Those are specified under `source_query.include`.

  Currently only historical periods are supported for comparisons (not `realtime`
  and `30m` periods).

  ## Modes (`source_query.include.compare` field)

    * `:previous_period` - shifts back the query by the same number of days the
        source query has.

    * `:year_over_year` - shifts back the query by 1 year.

    * `{:date_range, from, to}` - compares the query using a custom date range.

  ## Options

    * `source_query.include.compare_match_day_of_week`

      Determines whether the comparison query should be adjusted to match the
      day of the week of the source query. When this option is set to true, the
      comparison query is shifted to start on the same day of the week as the
      source query, rather than on the exact same date.

      Example: if the source query starts on Sunday, January 1st, 2023 and the
      `year_over_year` comparison query is configured to `match_day_of_week`, it
      will be shifted to start on Sunday, January 2nd, 2022 instead of January 1st.

      Note: this option has no effect when custom date range mode is used.

  """
  def get_comparison_utc_time_range(%Stats.Query{} = source_query) do
    datetime_range =
      case source_query.include.compare do
        {:datetime_range, from, to} ->
          DateTimeRange.new!(from, to)

        _ ->
          comparison_date_range = get_comparison_date_range(source_query)

          DateTimeRange.new!(
            comparison_date_range.first,
            comparison_date_range.last,
            source_query.timezone
          )
      end

    DateTimeRange.to_timezone(datetime_range, "Etc/UTC")
  end

  def get_comparison_query(
        %Query{comparison_utc_time_range: %DateTimeRange{} = comparison_range} = source_query
      ) do
    source_query
    |> Query.set(utc_time_range: comparison_range)
  end

  @doc """
  Builds comparison query that specifically filters for values appearing in the main query results.

  When querying for comparisons with dimensions and pagination, extra
  filters are added to ensure comparison query returns same set of results
  as main query.
  """
  def add_comparison_filters(comparison_query, main_results_list) do
    comparison_filters =
      Enum.flat_map(main_results_list, &build_comparison_filter(&1, comparison_query))

    comparison_query
    |> add_query_filters(comparison_filters)
  end

  defp add_query_filters(query, []), do: query

  defp add_query_filters(query, [filter]) do
    query
    |> Query.add_filter([:ignore_in_totals_query, filter])
    |> Query.set(pagination: nil)
  end

  defp add_query_filters(query, filters) do
    query
    |> Query.add_filter([:ignore_in_totals_query, [:or, filters]])
    |> Query.set(pagination: nil)
  end

  defp build_comparison_filter(%{dimensions: dimension_labels}, query) do
    query_filters =
      query.dimensions
      |> Enum.zip(dimension_labels)
      |> Enum.reject(fn {dimension, _label} -> Time.time_dimension?(dimension) end)
      |> Enum.map(fn {dimension, label} -> [:is, dimension, [label]] end)

    case query_filters do
      [] -> []
      [filter] -> [filter]
      filters -> [[:and, filters]]
    end
  end

  defp get_comparison_date_range(%Query{include: %{compare: :year_over_year}} = source_query) do
    source_date_range = Query.date_range(source_query, trim_trailing: true)

    start_date = source_date_range.first |> Date.shift(year: -1)
    diff_in_days = Date.diff(source_date_range.last, source_date_range.first)
    end_date = Date.add(start_date, diff_in_days)

    Date.range(start_date, end_date)
    |> maybe_match_day_of_week(source_date_range, source_query)
  end

  defp get_comparison_date_range(%Query{include: %{compare: :previous_period}} = source_query) do
    source_date_range = Query.date_range(source_query, trim_trailing: true)

    last = source_date_range.last
    diff_in_days = Date.diff(source_date_range.first, last) - 1

    new_first = Date.add(source_date_range.first, diff_in_days)
    new_last = Date.add(last, diff_in_days)

    Date.range(new_first, new_last)
    |> maybe_match_day_of_week(source_date_range, source_query)
  end

  defp get_comparison_date_range(%Query{include: %{compare: {:date_range, from_date, to_date}}}) do
    Date.range(from_date, to_date)
  end

  defp maybe_match_day_of_week(comparison_date_range, source_date_range, source_query) do
    if source_query.include.compare_match_day_of_week do
      day_to_match = Date.day_of_week(source_date_range.first)

      new_first =
        shift_to_nearest(
          day_to_match,
          comparison_date_range.first,
          source_date_range.first
        )

      days_shifted = Date.diff(new_first, comparison_date_range.first)
      new_last = Date.add(comparison_date_range.last, days_shifted)

      Date.range(new_first, new_last)
    else
      comparison_date_range
    end
  end

  defp shift_to_nearest(day_of_week, date, reject) do
    if Date.day_of_week(date) == day_of_week do
      date
    else
      [next_occurring(day_of_week, date), previous_occurring(day_of_week, date)]
      |> Enum.sort_by(&Date.diff(date, &1))
      |> Enum.reject(&(&1 == reject))
      |> List.first()
    end
  end

  defp next_occurring(day_of_week, date) do
    days_to_add = day_of_week - Date.day_of_week(date)
    days_to_add = if days_to_add > 0, do: days_to_add, else: days_to_add + 7

    Date.add(date, days_to_add)
  end

  defp previous_occurring(day_of_week, date) do
    days_to_subtract = Date.day_of_week(date) - day_of_week
    days_to_subtract = if days_to_subtract > 0, do: days_to_subtract, else: days_to_subtract + 7

    Date.add(date, -days_to_subtract)
  end
end
