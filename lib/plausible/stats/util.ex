defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @doc """
  `__internal_visits` is fetched when querying bounce rate and visit duration, as it
  is needed to calculate these from imported data. This function removes that metric
  from all entries in the results list.
  """
  def remove_internal_visits_metric(results, metrics) do
    if :bounce_rate in metrics or :visit_duration in metrics do
      results
      |> Enum.map(&Map.delete(&1, :__internal_visits))
    else
      results
    end
  end
end
