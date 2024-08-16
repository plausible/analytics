defmodule Plausible.Stats do
  use Plausible
  alias Plausible.Stats.QueryResult
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{
    Breakdown,
    Aggregate,
    Timeseries,
    CurrentVisitors,
    FilterSuggestions,
    QueryOptimizer,
    SQL
  }

  use Plausible.DebugReplayInfo

  def query(site, query) do
    include_sentry_replay_info()

    optimized_query = QueryOptimizer.optimize(query)

    optimized_query
    |> SQL.QueryBuilder.build(site)
    |> ClickhouseRepo.all(query: query)
    |> QueryResult.from(optimized_query)
  end

  def breakdown(site, query, metrics, pagination) do
    include_sentry_replay_info()
    Breakdown.breakdown(site, query, metrics, pagination)
  end

  def aggregate(site, query, metrics) do
    include_sentry_replay_info()
    Aggregate.aggregate(site, query, metrics)
  end

  def timeseries(site, query, metrics) do
    include_sentry_replay_info()
    Timeseries.timeseries(site, query, metrics)
  end

  def current_visitors(site, duration \\ Duration.new!(minute: -5)) do
    include_sentry_replay_info()
    CurrentVisitors.current_visitors(site, duration)
  end

  on_ee do
    def funnel(site, query, funnel) do
      include_sentry_replay_info()
      Plausible.Stats.Funnel.funnel(site, query, funnel)
    end
  end

  def filter_suggestions(site, query, filter_name, filter_search) do
    include_sentry_replay_info()
    FilterSuggestions.filter_suggestions(site, query, filter_name, filter_search)
  end
end
