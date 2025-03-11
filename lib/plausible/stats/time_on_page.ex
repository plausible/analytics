defmodule Plausible.Stats.TimeOnPage do
  @moduledoc """
  Module to check whether the new time on page metric is available.
  """

  def new_time_on_page_enabled?(site, user) do
    FunWithFlags.enabled?(:new_time_on_page, for: user) ||
      FunWithFlags.enabled?(:new_time_on_page, for: site)
  end

  def legacy_time_on_page_cutoff() do
    # Placeholder until we implement a more sophisticated way to determine the cutoff
    # Only used when `new_time_on_page` flag is enabled
    DateTime.utc_now() |> DateTime.shift(day: -4) |> DateTime.to_iso8601()
  end
end
