defmodule Plausible.Stats.Comparisons do
  @moduledoc """
  This module provides functions for comparing query periods.

  It allows you to compare a given period with a previous period or with the
  same period from the previous year. For example, you can compare this month's
  main graph with last month or with the same month from last year.
  """

  alias Plausible.Stats
  alias Plausible.Stats.{Query, DateTimeRange, Time}

  @spec get_comparison_query(Stats.Query.t(), map()) :: Stats.Query.t()
  @doc """
  Generates a comparison query based on the source query and comparison mode.

  Currently only historical periods are supported for comparisons (not `realtime`
  and `30m` periods).

  ## Options
    * `mode` (required) - specifies the type of comparison and can be one of the
  following:

      * `"previous_period"` - shifts back the query by the same number of days the
        source query has.

      * `"year_over_year"` - shifts back the query by 1 year.

      * `"custom"` - compares the query using a custom date range. See `date_range` for
        more details.

    * `:date_range` - a ISO-8601 date string pair used when mode is `"custom"`.

    * `:match_day_of_week` - determines whether the comparison query should be
      adjusted to match the day of the week of the source query. When this option
      is set to true, the comparison query is shifted to start on the same day of
      the week as the source query, rather than on the exact same date. For
      example, if the source query starts on Sunday, January 1st, 2023 and the
      `year_over_year` comparison query is configured to `match_day_of_week`,
      it will be shifted to start on Sunday, January 2nd, 2022 instead of
      January 1st. Defaults to false.

  """
  def get_comparison_query(%Stats.Query{} = source_query, options) do
    comparison_date_range = get_comparison_date_range(source_query, options)

    new_range =
      DateTimeRange.new!(
        comparison_date_range.first,
        comparison_date_range.last,
        source_query.timezone
      )
      |> DateTimeRange.to_timezone("Etc/UTC")

    source_query
    |> Query.set(utc_time_range: new_range)
    |> maybe_include_imported(source_query)
  end

  @doc """
  Builds comparison query after executing `main` query.

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
    Query.add_filter(query, [:ignore_in_totals_query, filter])
  end

  defp add_query_filters(query, filters) do
    Query.add_filter(query, [:ignore_in_totals_query, [:or, filters]])
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

  defp get_comparison_date_range(source_query, %{mode: "year_over_year"} = options) do
    source_date_range = Query.date_range(source_query)

    start_date = Date.add(source_date_range.first, -365)
    end_date = earliest(source_date_range.last, source_query.now) |> Date.add(-365)

    Date.range(start_date, end_date)
    |> maybe_match_day_of_week(source_date_range, options)
  end

  defp get_comparison_date_range(source_query, %{mode: "previous_period"} = options) do
    source_date_range = Query.date_range(source_query)

    last = earliest(source_date_range.last, source_query.now)
    diff_in_days = Date.diff(source_date_range.first, last) - 1

    new_first = Date.add(source_date_range.first, diff_in_days)
    new_last = Date.add(last, diff_in_days)

    Date.range(new_first, new_last)
    |> maybe_match_day_of_week(source_date_range, options)
  end

  defp get_comparison_date_range(source_query, %{mode: "custom"} = options) do
    DateTimeRange.to_date_range(options.date_range, source_query.timezone)
  end

  defp earliest(a, b) do
    if Date.compare(a, b) in [:eq, :lt], do: a, else: b
  end

  defp maybe_match_day_of_week(comparison_date_range, source_date_range, options) do
    if options[:match_day_of_week] do
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

  defp maybe_include_imported(query, source_query) do
    requested? = source_query.include.imports

    case Query.ensure_include_imported(query, requested?) do
      :ok ->
        struct!(query,
          include_imported: true,
          skip_imported_reason: nil,
          include: Map.put(query.include, :imports, true)
        )

      {:error, reason} ->
        struct!(query,
          include_imported: false,
          skip_imported_reason: reason,
          include: Map.put(query.include, :imports, requested?)
        )
    end
  end
end
