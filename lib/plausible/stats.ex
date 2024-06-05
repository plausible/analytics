defmodule Plausible.Stats do
  use Plausible
  use Plausible.ClickhouseRepo

  alias Plausible.Stats.{
    Breakdown,
    Aggregate,
    Timeseries,
    CurrentVisitors,
    FilterSuggestions
  }

  use Plausible.DebugReplayInfo

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

  def current_visitors(site) do
    include_sentry_replay_info()
    CurrentVisitors.current_visitors(site)
  end

  def query(site, query) do
    optimized_query = Plausible.Stats.QueryOptimizer.optimize(query)
    {event_q, session_q} = Plausible.Stats.Ecto.QueryBuilder.build(optimized_query, site)

    Plausible.ClickhouseRepo.parallel_tasks([
      run_query_task(event_q),
      run_query_task(session_q)
    ])
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

  defp run_query_task(nil), do: fn -> %{} end
  defp run_query_task(q), do: fn -> ClickhouseRepo.all(q) end
end
