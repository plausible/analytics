defmodule Plausible.Stats.TimeOnPage do
  @moduledoc """
  Module to check whether the new time on page metric is available.
  """

  def new_time_on_page_enabled?(site, user) do
    FunWithFlags.enabled?(:new_time_on_page, for: user) ||
      FunWithFlags.enabled?(:new_time_on_page, for: site)
  end

  def legacy_time_on_page_cutoff(site) do
    cutoff(site.legacy_time_on_page_cutoff, site.timezone)
  end

  defp cutoff(nil, _timezone), do: ""

  defp cutoff(date, timezone) do
    case DateTime.new(date, ~T[00:00:00], timezone) do
      {:ok, datetime} -> datetime
      {:gap, just_before, _just_after} -> just_before
      {:ambiguous, first_datetime, _second_datetime} -> first_datetime
    end
    |> DateTime.to_iso8601()
  end
end
