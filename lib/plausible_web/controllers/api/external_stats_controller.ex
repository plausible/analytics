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
    with :ok <- validate_date(params),
         :ok <- validate_period(params),
         :ok <- validate_metrics(params) do
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
    else
      {:error, msg} ->
        conn
        |> put_status(400)
        |> json(%{error: msg})
    end
  end

  def timeseries(conn, params) do
    with :ok <- validate_date(params),
         :ok <- validate_period(params),
         :ok <- validate_interval(params) do
      site = conn.assigns[:site]
      query = Query.from(site.timezone, params)

      {plot, labels} = Plausible.Stats.timeseries(site, query)

      graph =
        Enum.zip(labels, plot)
        |> Enum.map(fn {label, val} -> %{date: label, value: val} end)
        |> Enum.into([])

      json(conn, graph)
    else
      {:error, msg} ->
        conn
        |> put_status(400)
        |> json(%{error: msg})
    end
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

  defp validate_date(%{"date" => date}) do
    case Date.from_iso8601(date) do
      {:ok, _date} ->
        :ok

      {:error, msg} ->
        {:error,
         "Error parsing `date` parameter: #{msg}. Please specify a valid date in ISO-8601 format."}
    end
  end

  defp validate_date(_), do: :ok

  defp validate_period(%{"period" => period}) do
    if period in ["day", "7d", "30d", "month", "6mo", "12mo", "custom"] do
      :ok
    else
      {:error,
       "Error parsing `period` parameter: invalid period `#{period}`. Please find accepted values in our docs: https://plausible.io/docs/stats-api#time-periods"}
    end
  end

  defp validate_period(_), do: :ok

  @valid_metrics ["pageviews", "visitors", "bounce_rate", "visit_duration"]
  @valid_metrics_str Enum.map(@valid_metrics, &("`" <> &1 <> "`")) |> Enum.join(", ")

  defp validate_metrics(%{"metrics" => metrics_str}) do
    metrics =
      metrics_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    bad_metric = Enum.find(metrics, fn metric -> metric not in @valid_metrics end)

    if bad_metric do
      {:error,
       "Error parsing `metrics` parameter: invalid metric `#{bad_metric}`. Valid metrics are #{
         @valid_metrics_str
       }"}
    else
      :ok
    end
  end

  defp validate_metrics(_), do: :ok

  @valid_intervals ["date", "month"]
  @valid_intervals_str Enum.map(@valid_intervals, &("`" <> &1 <> "`")) |> Enum.join(", ")

  defp validate_interval(%{"interval" => interval}) do
    if interval in @valid_intervals do
      :ok
    else
      {:error,
       "Error parsing `interval` parameter: invalid interval `#{interval}`. Valid intervals are #{
         @valid_intervals_str
       }"}
    end
  end

  defp validate_interval(_), do: :ok
end
