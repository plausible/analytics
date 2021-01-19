defmodule PlausibleWeb.Api.ExternalStatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats.Clickhouse, as: Stats
  alias Plausible.Stats.Query

  @metric_queries %{
    "visitors" => &Stats.unique_visitors/2,
    "pageviews" => &Stats.total_pageviews/2,
    "bounce_rate" => &Stats.bounce_rate/2,
    "visit_duration" => &Stats.visit_duration/2
  }

  def realtime_visitors(conn, _params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, %{"period" => "realtime"})
    json(conn, Stats.current_visitors(site, query))
  end

  def aggregate(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    metrics =
      params["metrics"]
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn metric -> {metric, @metric_queries[metric]} end)
      |> Enum.filter(fn {_metric, fun} -> !!fun end)
      |> Enum.map(fn {metric, fun} -> {metric, Task.async(fn -> fun.(site, query) end)} end)
      |> Enum.map(fn {metric, task} -> {metric, %{value: Task.await(task)}} end)
      |> Enum.into(%{})

    json(conn, metrics)
  end

  def timeseries(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    {plot, labels} = Plausible.Stats.timeseries(site, query)

    graph =
      Enum.zip(labels, plot)
      |> Enum.map(fn {label, val} -> %{date: label, value: val} end)
      |> Enum.into([])

    json(conn, graph)
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end
end
