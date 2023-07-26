defmodule Plausible.Stats do
  alias Plausible.Stats.{
    Breakdown,
    Aggregate,
    Timeseries,
    CurrentVisitors,
    Funnel,
    FilterSuggestions
  }

  use Plausible.DebugReplayInfo

  def breakdown(site, query, prop, metrics, pagination) do
    include_sentry_replay_info()
    Breakdown.breakdown(site, query, prop, metrics, pagination)
  end

  def aggregate(site, query, metrics) do
    include_sentry_replay_info()
    Aggregate.aggregate(site, query, metrics)
  end

  def timeseries(site, query, metrics) do
    include_sentry_replay_info()
    Timeseries.timeseries(site, query, metrics)
  end

  def current_visitors(site) do
    include_sentry_replay_info()
    CurrentVisitors.current_visitors(site)
  end

  def funnel(site, query, funnel) do
    include_sentry_replay_info()
    Funnel.funnel(site, query, funnel)
  end

  def filter_suggestions(site, query, filter_name, filter_search) do
    include_sentry_replay_info()
    FilterSuggestions.filter_suggestions(site, query, filter_name, filter_search)
  end
end
