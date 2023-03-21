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
         {:ok, metrics} <- parse_and_validate_metrics(params, nil, query) do
      results =
        if params["compare"] == "previous_period" do
          {:ok, prev_query} = Plausible.Stats.Comparisons.compare(site, query, "previous_period")

          [prev_result, curr_result] =
            Plausible.ClickhouseRepo.parallel_tasks([
              fn -> Plausible.Stats.aggregate(site, prev_query, metrics) end,
              fn -> Plausible.Stats.aggregate(site, query, metrics) end
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

      results =
        results
        |> Map.take(metrics)

      json(conn, %{results: results})
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
         {:ok, metrics} <- parse_and_validate_metrics(params, property, query),
         {:ok, limit} <- validate_or_default_limit(params) do
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
    if Plausible.Stats.Props.valid_prop?(property) do
      {:ok, property}
    else
      {:error,
       "Invalid property '#{property}'. Please provide a valid property for the breakdown endpoint: https://plausible.io/docs/stats-api#properties"}
    end
  end

  defp validate_property(_) do
    {:error,
     "The `property` parameter is required. Please provide at least one property to show a breakdown by."}
  end

  @max_breakdown_limit 1000
  defp validate_or_default_limit(%{"limit" => limit}) do
    with {limit, ""} when limit > 0 and limit <= @max_breakdown_limit <- Integer.parse(limit) do
      {:ok, limit}
    else
      _ ->
        {:error, "Please provide limit as a number between 1 and #{@max_breakdown_limit}."}
    end
  end

  @default_breakdown_limit 100
  defp validate_or_default_limit(_), do: {:ok, @default_breakdown_limit}

  defp event_only_property?("event:name"), do: true
  defp event_only_property?("event:props:" <> _), do: true
  defp event_only_property?(_), do: false

  @event_metrics ["visitors", "pageviews", "events"]
  @session_metrics ["visits", "bounce_rate", "visit_duration", "views_per_visit"]
  defp parse_and_validate_metrics(params, property, query) do
    metrics =
      Map.get(params, "metrics", "visitors")
      |> String.split(",")

    case validate_all_metrics(metrics, property, query) do
      {:error, reason} -> {:error, reason}
      metrics -> {:ok, Enum.map(metrics, &String.to_atom/1)}
    end
  end

  defp validate_all_metrics(metrics, property, query) do
    Enum.reduce_while(metrics, [], fn metric, acc ->
      case validate_metric(metric, property, query) do
        {:ok, metric} -> {:cont, acc ++ [metric]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_metric(metric, _, _) when metric in @event_metrics, do: {:ok, metric}

  defp validate_metric(metric, property, query) when metric in @session_metrics do
    event_only_filter = Map.keys(query.filters) |> Enum.find(&event_only_property?/1)

    cond do
      metric == "views_per_visit" && property != nil ->
        {:error, "Metric `#{metric}` is not supported in breakdown queries"}

      event_only_property?(property) ->
        {:error, "Session metric `#{metric}` cannot be queried for breakdown by `#{property}`."}

      event_only_filter ->
        {:error,
         "Session metric `#{metric}` cannot be queried when using a filter on `#{event_only_filter}`."}

      true ->
        {:ok, metric}
    end
  end

  defp validate_metric(metric, _, _) do
    {:error,
     "The metric `#{metric}` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#metrics"}
  end

  def timeseries(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "sample_threshold", "infinite")

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         :ok <- validate_interval(params),
         query <- Query.from(site, params),
         {:ok, metrics} <- parse_and_validate_metrics(params, nil, query) do
      graph = Plausible.Stats.timeseries(site, query, metrics)

      json(conn, %{results: graph})
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
