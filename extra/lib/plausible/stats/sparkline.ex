defmodule Plausible.Stats.Sparkline do
  @moduledoc """
  Module used to generate sparkline overview data for sites, including consolidated views.
  The sparkline graphs are used in site index and in CRM.
  """

  alias Plausible.{Site, Stats}
  alias Plausible.Stats.QueryBuilder
  require Logger

  @spec parallel_overview([Site.t()], NaiveDateTime.t()) :: map()
  def parallel_overview(sites, now \\ NaiveDateTime.utc_now()) when is_list(sites) do
    try do
      Task.async_stream(
        sites,
        fn site ->
          {site.domain, safe_overview_24h(site, now)}
        end,
        timeout: 5000,
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {domain, {:ok, stats}}}, acc ->
          Map.put(acc, domain, stats)

        _, acc ->
          acc
      end)
    catch
      kind, value ->
        Logger.error("Could not render sparkline: #{inspect(kind)} #{inspect(value)}")

        %{}
    end
  end

  @spec overview_24h(Site.t(), NaiveDateTime.t()) :: map()
  def overview_24h(view_or_site, now \\ NaiveDateTime.utc_now()) do
    stats = query_24h_stats(view_or_site, now)
    intervals = query_24h_intervals(view_or_site, now)

    Map.merge(stats, intervals)
  end

  @spec safe_overview_24h(Site.t(), NaiveDateTime.t()) ::
          {:ok, map()} | {:error, :inaccessible} | {:error, :not_found}

  def safe_overview_24h(site, now \\ NaiveDateTime.utc_now())
  def safe_overview_24h(nil, _now), do: {:error, :not_found}

  def safe_overview_24h(%Site{} = view, now) do
    try do
      {:ok, overview_24h(view, now)}
    catch
      kind, value ->
        Logger.error("Could not render overview 24h: #{inspect(kind)} #{inspect(value)}")

        IO.inspect(__STACKTRACE__, label: "Stacktrace")

        {:error, :inaccessible}
    end
  end

  def empty_24h_intervals(now \\ NaiveDateTime.utc_now()) do
    first = NaiveDateTime.add(now, -24, :hour)
    {:ok, time} = Time.new(first.hour, 0, 0)
    first = NaiveDateTime.new!(NaiveDateTime.to_date(first), time)

    for offset <- 0..24, into: %{} do
      {NaiveDateTime.add(first, offset, :hour), 0}
    end
  end

  defp query_24h_stats(view_or_site, now) do
    stats_query =
      QueryBuilder.build!(view_or_site,
        fixed_now: DateTime.from_naive!(now, "Etc/UTC"),
        input_date_range: :"24h",
        metrics: [:visitors, :visits, :pageviews, :views_per_visit],
        include: [compare: :previous_period]
      )

    %Stats.QueryResult{
      results: [
        %{
          metrics: [visitors, visits, pageviews, views_per_visit],
          comparison: %{
            change: [visitors_change, visits_change, pageviews_change, views_per_visit_change]
          }
        }
      ]
    } = Stats.query(view_or_site, stats_query)

    %{
      visitors: visitors,
      visits: visits,
      pageviews: pageviews,
      views_per_visit: views_per_visit,
      visitors_change: visitors_change,
      visits_change: visits_change,
      pageviews_change: pageviews_change,
      views_per_visit_change: views_per_visit_change
    }
  end

  defp query_24h_intervals(view_or_site, now) do
    graph_query =
      QueryBuilder.build!(view_or_site,
        fixed_now: DateTime.from_naive!(now, "Etc/UTC"),
        metrics: [:visitors],
        input_date_range: :"24h",
        dimensions: ["time:hour"],
        order_by: [{"time:hour", :asc}]
      )

    %Stats.QueryResult{results: results} = Stats.query(view_or_site, graph_query)

    placeholder =
      empty_24h_intervals(now)

    results =
      Enum.map(
        results,
        fn %{metrics: [visitors], dimensions: [timestamp]} ->
          {NaiveDateTime.from_iso8601!(timestamp), visitors}
        end
      )
      |> Enum.into(%{})

    graph_data =
      placeholder
      |> Enum.reduce([], fn {interval, 0}, acc ->
        [{interval, results[interval] || 0} | acc]
      end)
      |> Enum.sort_by(fn {interval, _} -> interval end, NaiveDateTime)

    %{
      intervals: Enum.map(graph_data, fn {k, v} -> %{interval: k, visitors: v} end)
    }
  end
end
