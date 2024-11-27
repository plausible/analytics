defmodule Plausible.Stats.EmailReport do
  @moduledoc """
  This module exposes a `get/2` function that returns a map
  of stats needed for email reports. These stats include:

  * Total pageviews
  * Unique visitors
  * Bounce rate
  * A list of Top 5 sources (excluding "Direct / None")
  * A list of Top 5 pages

  where total pageviews, unique visitors, and bounce rate
  also include the change compared to previous period.
  """

  alias Plausible.Stats
  alias Plausible.Stats.{Query, Compare, Comparisons}

  def get(site, query) do
    metrics = [:pageviews, :visitors, :bounce_rate]

    Stats.aggregate(site, query, metrics)
    |> with_comparisons(site, query, metrics)
    |> put_top_5_pages(site, query)
    |> put_top_5_sources(site, query)
  end

  defp with_comparisons(stats, site, query, metrics) do
    comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})
    prev_period_stats = Stats.aggregate(site, comparison_query, metrics)

    stats
    |> Enum.map(fn {metric, %{value: value}} ->
      %{value: prev_value} = Map.fetch!(prev_period_stats, metric)
      change = Compare.calculate_change(metric, prev_value, value)

      {metric, %{value: value, change: change}}
    end)
    |> Enum.into(%{})
  end

  defp put_top_5_pages(stats, site, query) do
    query = Query.set(query, dimensions: ["event:page"])
    pages = Stats.breakdown(site, query, [:visitors], {5, 1})
    Map.put(stats, :pages, pages)
  end

  defp put_top_5_sources(stats, site, query) do
    query =
      query
      |> Query.add_filter([:is_not, "visit:source", ["Direct / None"], %{}])
      |> Query.set(dimensions: ["visit:source"])

    sources = Stats.breakdown(site, query, [:visitors], {5, 1})

    Map.put(stats, :sources, sources)
  end
end
