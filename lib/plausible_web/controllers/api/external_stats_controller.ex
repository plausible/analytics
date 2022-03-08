defmodule PlausibleWeb.Api.ExternalStatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats.{Query, Props}

  def realtime_visitors(conn, _params) do
    site = conn.assigns[:site]
    query = Query.from(site, %{"period" => "realtime"})
    json(conn, Plausible.Stats.Clickhouse.current_visitors(site, query))
  end

  def aggregate(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "sample_threshold", "infinite")

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         query <- Query.from(site, params),
         {:ok, metrics} <- parse_metrics(params, nil, query) do
      results =
        if params["compare"] == "previous_period" do
          prev_query = Query.shift_back(query, site)

          [prev_result, curr_result] =
            Task.await_many(
              [
                Task.async(fn -> Plausible.Stats.aggregate(site, prev_query, metrics) end),
                Task.async(fn -> Plausible.Stats.aggregate(site, query, metrics) end)
              ],
              10_000
            )

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

      json(conn, %{results: Map.take(results, metrics)})
    else
      {:error, msg} ->
        conn
        |> put_status(400)
        |> json(%{error: msg})
    end
  end

  def breakdown(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "sample_threshold", "infinite")

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         {:ok, property} <- validate_property(params),
         query <- Query.from(site, params),
         {:ok, metrics} <- parse_metrics(params, property, query) do
      limit = String.to_integer(Map.get(params, "limit", "100"))
      page = String.to_integer(Map.get(params, "page", "1"))
      results = Plausible.Stats.breakdown(site, query, property, metrics, {limit, page})

      results =
        if property == "event:goal" do
          prop_names = Props.props(site, query)

          Enum.map(results, fn row ->
            Map.put(row, "props", prop_names[row[:goal]] || [])
          end)
        else
          results
        end

      json(conn, %{results: results})
    else
      {:error, msg} ->
        conn
        |> put_status(400)
        |> json(%{error: msg})
    end
  end

  defp validate_property(%{"property" => property}) do
    {:ok, property}
  end

  defp validate_property(_) do
    {:error,
     "The `property` parameter is required. Please provide at least one property to show a breakdown by."}
  end

  defp event_only_property?("event:name"), do: true
  defp event_only_property?("event:props:" <> _), do: true
  defp event_only_property?(_), do: false

  @event_metrics ["visitors", "pageviews", "events"]
  @session_metrics ["visits", "bounce_rate", "visit_duration"]
  defp parse_metrics(params, property, query) do
    metrics =
      Map.get(params, "metrics", "visitors")
      |> String.split(",")

    event_only_filter = Map.keys(query.filters) |> Enum.find(&event_only_property?/1)

    valid_metrics =
      if event_only_property?(property) || event_only_filter do
        @event_metrics
      else
        @event_metrics ++ @session_metrics
      end

    invalid_metric = Enum.find(metrics, fn metric -> metric not in valid_metrics end)

    if invalid_metric do
      cond do
        event_only_property?(property) && invalid_metric in @session_metrics ->
          {:error,
           "Session metric `#{invalid_metric}` cannot be queried for breakdown by `#{property}`."}

        event_only_filter && invalid_metric in @session_metrics ->
          {:error,
           "Session metric `#{invalid_metric}` cannot be queried when using a filter on `#{event_only_filter}`."}

        true ->
          {:error,
           "The metric `#{invalid_metric}` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#get-apiv1statsbreakdown"}
      end
    else
      {:ok, Enum.map(metrics, &String.to_atom/1)}
    end
  end

  def timeseries(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "sample_threshold", "infinite")

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         :ok <- validate_interval(params),
         query <- Query.from(site, params),
         {:ok, metrics} <- parse_metrics(params, nil, query) do
      graph = Plausible.Stats.timeseries(site, query, metrics)
      metrics = metrics ++ [:date]
      json(conn, %{results: Enum.map(graph, &Map.take(&1, metrics))})
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

  defp validate_date(%{"period" => "custom"} = params) do
    with {:ok, date} <- Map.fetch(params, "date"),
         [from, to] <- String.split(date, ","),
         {:ok, _from} <- Date.from_iso8601(String.trim(from)),
         {:ok, _to} <- Date.from_iso8601(String.trim(to)) do
      :ok
    else
      :error ->
        {:error,
         "The `date` parameter is required when using a custom period. See https://plausible.io/docs/stats-api#time-periods"}

      _ ->
        {:error,
         "Invalid format for `date` parameter. When using a custom period, please include two ISO-8601 formatted dates joined by a comma. See https://plausible.io/docs/stats-api#time-periods"}
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

  @valid_intervals ["date", "month"]
  @valid_intervals_str Enum.map(@valid_intervals, &("`" <> &1 <> "`")) |> Enum.join(", ")

  defp validate_interval(%{"interval" => interval}) do
    if interval in @valid_intervals do
      :ok
    else
      {:error,
       "Error parsing `interval` parameter: invalid interval `#{interval}`. Valid intervals are #{@valid_intervals_str}"}
    end
  end

  defp validate_interval(_), do: :ok
end
