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

  @spec compare(Plausible.Site.t(), Stats.Query.t(), String.t()) ::
          {:ok, Stats.Query.t()} | {:error, :not_supported}
  def compare(%Plausible.Site{} = site, %Stats.Query{} = source_query, mode) do
    if valid_mode?(source_query, mode) do
      {:ok, do_compare(site, source_query, mode)}
    else
      {:error, :not_supported}
    end
  end

  defp do_compare(site, source_query, "previous_period") do
    Stats.Query.shift_back(source_query, site)
  end

  defp do_compare(_site, source_query, "year_over_year") do
    start_date = Date.add(source_query.date_range.first, -365)
    end_date = Date.add(source_query.date_range.last, -365)
    range = Date.range(start_date, end_date)

    %Stats.Query{source_query | date_range: range}
  end

  @spec valid_mode?(Stats.Query.t(), String.t()) :: boolean()
  @doc """
  Returns whether the source query and the selected mode support comparisons.

  For example, the realtime view doesn't support comparisons. Additionally, only
  #{inspect(@modes)} are supported.
  """
  def valid_mode?(%Stats.Query{period: period}, mode) do
    mode in @modes && period not in @disallowed_periods
  end
end
