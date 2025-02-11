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
  alias Plausible.Stats.{Query, QueryResult}

  def get(site, query) do
    aggregate_and_compare(site, query)
    |> put_top_5_pages(site, query)
    |> put_top_5_sources(site, query)
  end

  defp aggregate_and_compare(site, query) do
    metrics = [:pageviews, :visitors, :bounce_rate]

    query =
      query
      |> Query.set(metrics: metrics)
      |> Query.set_include(:comparisons, %{mode: "previous_period"})
      |> Query.put_comparison_utc_time_range()

    %QueryResult{results: [result]} = Plausible.Stats.query(site, query)

    metrics
    |> Enum.with_index()
    |> Enum.map(fn {metric, idx} ->
      value = Enum.at(result.metrics, idx)
      change = Enum.at(result.comparison.change, idx)

      {metric, %{value: value, change: change}}
    end)
    |> Enum.into(%{})
  end

  defp put_top_5_pages(stats, site, query) do
    query = Query.set(query, dimensions: ["event:page"])
    %{results: pages} = Stats.breakdown(site, query, [:visitors], {5, 1})
    Map.put(stats, :pages, pages)
  end

  defp put_top_5_sources(stats, site, query) do
    query =
      query
      |> Query.add_filter([:is_not, "visit:source", ["Direct / None"]])
      |> Query.set(dimensions: ["visit:source"])

    %{results: sources} = Stats.breakdown(site, query, [:visitors], {5, 1})

    Map.put(stats, :sources, sources)
  end
end
