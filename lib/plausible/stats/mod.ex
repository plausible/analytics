defmodule Plausible.Stats do
  defdelegate breakdown(site, query, prop, metrics, pagination), to: Plausible.Stats.Breakdown
  defdelegate aggregate(site, query, metrics), to: Plausible.Stats.Aggregate
  defdelegate timeseries(site, query, metrics), to: Plausible.Stats.Timeseries
end
