defmodule Plausible.Stats.Comparisons do
  @moduledoc """
  This module provides functions for comparing query periods.

  It allows you to compare a given period with a previous period or with the
  same period from the previous year. For example, you can compare this month's
  main graph with last month or with the same month from last year.
  """

  alias Plausible.Stats

  @modes ~w(previous_period year_over_year custom)
  @disallowed_periods ~w(realtime all)

  @type mode() :: String.t() | nil
  @typep option() :: {:from, String.t()} | {:to, String.t()} | {:now, NaiveDateTime.t()}

  @spec compare(Plausible.Site.t(), Stats.Query.t(), mode(), [option()]) ::
          {:ok, Stats.Query.t()} | {:error, :not_supported} | {:error, :invalid_dates}
  @doc """
  Generates a comparison query based on the source query and comparison mode.

  The mode parameter specifies the type of comparison and can be one of the
  following:

    * `"previous_period"` - shifts back the query by the same number of days the
      source query has.

    * `"year_over_year"` - shifts back the query by 1 year.

    * `"custom"` - compares the query using a custom date range. See options for
      more details.

  The comparison query returned by the function has its end date restricted to
  the current day. This can be overriden by the `now` option, described below.

  ## Options

    * `:now` - a `NaiveDateTime` struct with the current date and time. This is
      optional and used for testing purposes.

    * `:from` - a ISO-8601 date string used when mode is `"custom"`.

    * `:to` - a ISO-8601 date string used when mode is `"custom"`. Must be
      after `from`.

    * `:match_day_of_week?` - determines whether the comparison query should be
      adjusted to match the day of the week of the source query. When this option
      is set to true, the comparison query is shifted to start on the same day of
      the week as the source query, rather than on the exact same date. For
      example, if the source query starts on Sunday, January 1st, 2023 and the
      `year_over_year` comparison query is configured to `match_day_of_week?`,
      it will be shifted to start on Sunday, January 2nd, 2022 instead of
      January 1st. Defaults to false.

  """
  def compare(%Plausible.Site{} = site, %Stats.Query{} = source_query, mode, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:now, Timex.now(site.timezone))
      |> Keyword.put_new(:match_day_of_week?, false)

    with :ok <- validate_mode(source_query, mode),
         {:ok, comparison_query} <- do_compare(source_query, mode, opts),
         comparison_query <- maybe_include_imported(comparison_query, source_query, site),
         do: {:ok, comparison_query}
  end

  defp do_compare(source_query, "year_over_year", opts) do
    now = Keyword.fetch!(opts, :now)

    start_date = Date.add(source_query.date_range.first, -365)
    end_date = earliest(source_query.date_range.last, now) |> Date.add(-365)

    range = Date.range(start_date, end_date)

    comparison_query =
      source_query
      |> Map.put(:date_range, range)
      |> maybe_match_day_of_week(source_query, opts)

    {:ok, comparison_query}
  end

  defp do_compare(source_query, "previous_period", opts) do
    now = Keyword.fetch!(opts, :now)

    last = earliest(source_query.date_range.last, now)
    diff_in_days = Date.diff(source_query.date_range.first, last) - 1

    new_first = Date.add(source_query.date_range.first, diff_in_days)
    new_last = Date.add(last, diff_in_days)

    range = Date.range(new_first, new_last)

    comparison_query =
      source_query
      |> Map.put(:date_range, range)
      |> maybe_match_day_of_week(source_query, opts)

    {:ok, comparison_query}
  end

  defp do_compare(source_query, "custom", opts) do
    with {:ok, from} <- opts |> Keyword.fetch!(:from) |> Date.from_iso8601(),
         {:ok, to} <- opts |> Keyword.fetch!(:to) |> Date.from_iso8601(),
         result when result in [:eq, :lt] <- Date.compare(from, to) do
      {:ok, %Stats.Query{source_query | date_range: Date.range(from, to)}}
    else
      _error -> {:error, :invalid_dates}
    end
  end

  defp earliest(a, b) do
    if Date.compare(a, b) in [:eq, :lt], do: a, else: b
  end

  defp maybe_match_day_of_week(comparison_query, source_query, opts) do
    if Keyword.fetch!(opts, :match_day_of_week?) do
      day_to_match = Date.day_of_week(source_query.date_range.first)

      new_first =
        shift_to_nearest(
          day_to_match,
          comparison_query.date_range.first,
          source_query.date_range.first
        )

      days_shifted = Date.diff(new_first, comparison_query.date_range.first)
      new_last = Date.add(comparison_query.date_range.last, days_shifted)

      new_range = Date.range(new_first, new_last)
      %Stats.Query{comparison_query | date_range: new_range}
    else
      comparison_query
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

  defp maybe_include_imported(query, source_query, site) do
    requested? = source_query.imported_data_requested
    include_imported? = Stats.Query.include_imported?(query, site, requested?)
    %Stats.Query{query | include_imported: include_imported?}
  end

  defp validate_mode(%Stats.Query{period: period}, mode) do
    if mode in @modes && period not in @disallowed_periods do
      :ok
    else
      {:error, :not_supported}
    end
  end
end
