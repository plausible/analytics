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

    result =
      if params["compare"] == "previous_period" do
        prev_query = Query.shift_back(query)

        [prev_result, curr_result] =
          Task.await_many([
            Task.async(fn -> Plausible.Stats.aggregate(site, prev_query, metrics) end),
            Task.async(fn -> Plausible.Stats.aggregate(site, query, metrics) end)
          ])

        Enum.map(curr_result, fn {metric, %{value: current_val}} ->
          %{value: prev_val} = prev_result[metric]

          {metric,
           %{
             value: current_val,
             change: percent_change(prev_val, current_val)
           }}
        end)
        |> Enum.into(%{})
      else
        Plausible.Stats.aggregate(site, query, metrics)
      end

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

  defp percent_change(old_count, new_count) do
    cond do
      old_count == 0 and new_count > 0 ->
        100

      old_count == 0 and new_count == 0 ->
        0

      true ->
        round((new_count - old_count) / old_count * 100)
    end
  end
end
