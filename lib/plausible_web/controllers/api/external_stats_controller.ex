defmodule PlausibleWeb.Api.ExternalStatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats.Query

  def realtime_visitors(conn, _params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, %{"period" => "realtime"})
    json(conn, Plausible.Stats.Clickhouse.current_visitors(site, query))
  end

  def aggregate(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site.timezone, params)

    metrics =
      params["metrics"]
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    result = Plausible.Stats.aggregate(site, query, metrics)
    json(conn, result)
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
