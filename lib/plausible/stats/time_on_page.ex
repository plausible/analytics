defmodule Plausible.Stats.TimeOnPage do
  @moduledoc """
  Module to check whether the new time on page metric is available.
  """

  def new_time_on_page_enabled?(site, user) do
    FunWithFlags.enabled?(:new_time_on_page, for: user) ||
      FunWithFlags.enabled?(:new_time_on_page, for: site)
  end

  def new_time_on_page_visible?(site, user) do
    new_time_on_page_enabled?(site, user) && not is_nil(site.legacy_time_on_page_cutoff)
  end

  def legacy_time_on_page_cutoff_iso8601(site) do
    case cutoff(site.legacy_time_on_page_cutoff, site.timezone) do
      nil -> ""
      datetime -> DateTime.to_iso8601(datetime)
    end
  end

  def legacy_time_on_page_cutoff(site) do
    cutoff(site.legacy_time_on_page_cutoff, site.timezone)
  end

  defp cutoff(nil, _timezone), do: nil

  # Workaround for a case where casting unix epoch to DateTime fails for sites that should
  # always have the new time-on-page only. Affects CSV imports.
  defp cutoff(~D[1970-01-01], _timezone), do: ~U[2000-01-01 00:00:00Z]

  defp cutoff(date, timezone) do
    case DateTime.new(date, ~T[00:00:00], timezone) do
      {:ok, datetime} -> datetime
      {:gap, just_before, _just_after} -> just_before
      {:ambiguous, first_datetime, _second_datetime} -> first_datetime
    end
  end
end
