defmodule Plausible.Stats.TimeOnPage do
  @moduledoc """
  Module to check whether the new time on page metric is available.
  """

  def new_time_on_page_visible?(site) do
    not is_nil(site.legacy_time_on_page_cutoff)
  end

  def legacy_time_on_page_cutoff(site) do
    cutoff_datetime(site.legacy_time_on_page_cutoff, site.timezone)
  end

  def cutoff_datetime(nil, _timezone), do: nil

  # Workaround for a case where casting unix epoch to DateTime fails for sites that should
  # always have the new time-on-page only. Affects CSV imports.
  def cutoff_datetime(~D[1970-01-01], _timezone), do: ~U[2000-01-01 00:00:00Z]

  def cutoff_datetime(date, timezone) do
    case DateTime.new(date, ~T[00:00:00], timezone) do
      {:ok, datetime} -> datetime
      {:gap, just_before, _just_after} -> just_before
      {:ambiguous, first_datetime, _second_datetime} -> first_datetime
    end
  end
end
