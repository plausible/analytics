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

  """
  def compare(%Plausible.Site{} = site, %Stats.Query{} = source_query, mode, opts \\ []) do
    if valid_mode?(source_query, mode) do
      opts = Keyword.put_new(opts, :now, Timex.now(site.timezone))
      do_compare(source_query, mode, opts)
    else
      {:error, :not_supported}
    end
  end

  defp do_compare(source_query, "year_over_year", opts) do
    now = Keyword.fetch!(opts, :now)

    start_date = Date.add(source_query.date_range.first, -365)
    end_date = earliest(source_query.date_range.last, now) |> Date.add(-365)

    range = Date.range(start_date, end_date)
    {:ok, %Stats.Query{source_query | date_range: range}}
  end

  defp do_compare(source_query, "previous_period", opts) do
    now = Keyword.fetch!(opts, :now)

    last = earliest(source_query.date_range.last, now)
    diff_in_days = Date.diff(source_query.date_range.first, last) - 1

    new_first = Date.add(source_query.date_range.first, diff_in_days)
    new_last = Date.add(last, diff_in_days)

    range = Date.range(new_first, new_last)
    {:ok, %Stats.Query{source_query | date_range: range}}
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

  @spec valid_mode?(Stats.Query.t(), mode()) :: boolean()
  @doc """
  Returns whether the source query and the selected mode support comparisons.

  For example, the realtime view doesn't support comparisons. Additionally, only
  #{inspect(@modes)} are supported.
  """
  def valid_mode?(%Stats.Query{period: period}, mode) do
    mode in @modes && period not in @disallowed_periods
  end
end
