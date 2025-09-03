defmodule Plausible.Stats.EmailReport do
  @moduledoc """
  This module exposes functions that return a map of stats needed for email reports.
  These stats include:

  * Total pageviews
  * Unique visitors
  * Bounce rate
  * A list of Top 5 sources (excluding "Direct / None")
  * A list of Top 5 pages
  * A list of Top 5 goals (when goals exist)

  where total pageviews, unique visitors, and bounce rate
  also include the change compared to previous period.
  """

  alias Plausible.Stats
  alias Plausible.Stats.{Query, QueryResult}

  @aggregate_metrics [:pageviews, :visitors, :bounce_rate]

  def get_for_period(site, period, date) when period in ["7d", "month"] do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          # metrics will be overridden in the pipeline that follows, and the build interface forces us to pass something
          "metrics" => ["visitors"],
          "date_range" => period,
          "date" => date
        },
        %{}
      )

    site
    |> aggregate_and_compare(query)
    |> put_top_5_pages(site, query)
    |> put_top_5_sources(site, query)
    |> put_top_5_goals(site, query)
  end

  defp aggregate_and_compare(site, query) do
    query =
      query
      |> Query.set(metrics: @aggregate_metrics)
      |> Query.set_include(:comparisons, %{mode: "previous_period"})
      |> Query.put_comparison_utc_time_range()

    %QueryResult{results: [result]} = Plausible.Stats.query(site, query)

    @aggregate_metrics
    |> Enum.with_index()
    |> Enum.into(%{}, fn {metric, idx} ->
      value = Enum.at(result.metrics, idx)
      change = Enum.at(result.comparison.change, idx)

      {metric, %{value: value, change: change}}
    end)
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

  defp put_top_5_goals(stats, site, query) do
    period_str = if query.period == "month", do: "month", else: "7d"

    {:ok, q} =
      Query.build(
        site,
        :internal,
        %{
          # site_id parameter is required, but it doesn't matter what we pass here since the query is executed against a specific site later on
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "dimensions" => ["event:goal"],
          "date_range" => period_str,
          "pagination" => %{"limit" => 5}
        },
        %{}
      )

    goals =
      site
      |> Plausible.Stats.query(q)
      |> Map.fetch!(:results)
      |> Enum.map(fn %{metrics: [visitors], dimensions: [goal_name]} ->
        %{
          goal: goal_name,
          visitors: visitors
        }
      end)

    Map.put(stats, :goals, goals)
  end
end
