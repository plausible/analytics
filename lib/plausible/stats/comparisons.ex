defmodule Plausible.Stats.Comparisons do
  @moduledoc """
  This module provides functions for comparing query periods.

  It allows you to compare a given period with a previous period or with the
  same period from the previous year. For example, you can compare this month's
  main graph with last month or with the same month from last year.
  """

  alias Plausible.Stats

  @modes ~w(previous_period year_over_year)
  @disallowed_periods ~w(realtime all)

  @type mode() :: String.t() | nil

  @spec compare(
          Plausible.Site.t(),
          Stats.Query.t(),
          mode(),
          NaiveDateTime.t()
        ) :: {:ok, Stats.Query.t()} | {:error, :not_supported}
  def compare(
        %Plausible.Site{} = site,
        %Stats.Query{} = source_query,
        mode,
        now \\ nil
      ) do
    if valid_mode?(source_query, mode) do
      now = now || Timex.now(site.timezone)
      {:ok, do_compare(site, source_query, mode, now)}
    else
      {:error, :not_supported}
    end
  end

  defp do_compare(_site, source_query, "year_over_year", now) do
    start_date = Date.add(source_query.date_range.first, -365)
    end_date = earliest(source_query.date_range.last, now) |> Date.add(-365)

    range = Date.range(start_date, end_date)
    %Stats.Query{source_query | date_range: range}
  end

  defp do_compare(_site, %Stats.Query{period: "year"} = query, "previous_period", now) do
    # Querying current year to date
    {new_first, new_last} =
      if Timex.compare(now, query.date_range.first, :year) == 0 do
        diff =
          Timex.diff(
            Timex.beginning_of_year(now),
            now,
            :days
          ) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         now |> Timex.to_date() |> Timex.shift(days: diff)}
      else
        diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         query.date_range.last |> Timex.shift(days: diff)}
      end

    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  defp do_compare(_site, %Stats.Query{period: "month"} = query, "previous_period", now) do
    # Querying current month to date
    {new_first, new_last} =
      if Timex.compare(now, query.date_range.first, :month) == 0 do
        diff =
          Timex.diff(
            Timex.beginning_of_month(now),
            now,
            :days
          ) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         now |> Timex.to_date() |> Timex.shift(days: diff)}
      else
        diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1

        {query.date_range.first |> Timex.shift(days: diff),
         query.date_range.last |> Timex.shift(days: diff)}
      end

    Map.put(query, :date_range, Date.range(new_first, new_last))
  end

  defp do_compare(_site, query, "previous_period", _now) do
    diff = Timex.diff(query.date_range.first, query.date_range.last, :days) - 1
    new_first = query.date_range.first |> Timex.shift(days: diff)
    new_last = query.date_range.last |> Timex.shift(days: diff)
    Map.put(query, :date_range, Date.range(new_first, new_last))
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
