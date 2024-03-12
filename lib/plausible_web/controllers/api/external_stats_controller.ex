defmodule PlausibleWeb.Api.ExternalStatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.{Query, Compare, Comparisons}

  @metrics [
    :visitors,
    :visits,
    :pageviews,
    :views_per_visit,
    :bounce_rate,
    :visit_duration,
    :events,
    :conversion_rate
  ]

  @metric_mappings Enum.into(@metrics, %{}, fn metric -> {to_string(metric), metric} end)

  def realtime_visitors(conn, _params) do
    site = conn.assigns.site
    query = Query.from(site, %{"period" => "realtime"})
    json(conn, Plausible.Stats.Clickhouse.current_visitors(site, query))
  end

  def aggregate(conn, params) do
    site = Repo.preload(conn.assigns.site, :owner)

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         query <- Query.from(site, params),
         :ok <- validate_goal_filter(site, query.filters),
         {:ok, metrics} <- parse_and_validate_metrics(params, nil, query),
         :ok <- ensure_custom_props_access(site, query) do
      results =
        if params["compare"] == "previous_period" do
          {:ok, prev_query} = Comparisons.compare(site, query, "previous_period")

          [prev_result, curr_result] =
            Plausible.ClickhouseRepo.parallel_tasks([
              fn -> Plausible.Stats.aggregate(site, prev_query, metrics) end,
              fn -> Plausible.Stats.aggregate(site, query, metrics) end
            ])

          Enum.map(curr_result, fn {metric, %{value: current_val}} ->
            %{value: prev_val} = prev_result[metric]
            change = Compare.calculate_change(metric, prev_val, current_val)

            {metric, %{value: current_val, change: change}}
          end)
          |> Enum.into(%{})
        else
          Plausible.Stats.aggregate(site, query, metrics)
        end

      json(conn, %{results: results})
    else
      err_tuple -> send_json_error_response(conn, err_tuple)
    end
  end

  def breakdown(conn, params) do
    site = Repo.preload(conn.assigns.site, :owner)

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         {:ok, property} <- validate_property(params),
         query <- Query.from(site, params),
         :ok <- validate_goal_filter(site, query.filters),
         {:ok, metrics} <- parse_and_validate_metrics(params, property, query),
         {:ok, limit} <- validate_or_default_limit(params),
         :ok <- ensure_custom_props_access(site, query, property) do
      page = String.to_integer(Map.get(params, "page", "1"))
      results = Plausible.Stats.breakdown(site, query, property, metrics, {limit, page})

      json(conn, %{results: results})
    else
      err_tuple -> send_json_error_response(conn, err_tuple)
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

  defp parse_and_validate_metrics(params, property, query) do
    metrics =
      Map.get(params, "metrics", "visitors")
      |> String.split(",")

    case validate_metrics(metrics, property, query) do
      {:error, reason} ->
        {:error, reason}

      metrics ->
        {:ok, Enum.map(metrics, &Map.fetch!(@metric_mappings, &1))}
    end
  end

  @spec ensure_custom_props_access(Plausible.Site.t(), Query.t(), String.t() | nil) ::
          :ok | {:error, {402, String.t()}}
  defp ensure_custom_props_access(site, query, property \\ nil) do
    allowed_props = Plausible.Props.allowed_for(site, bypass_setup?: true)
    prop_filter = Query.get_filter_by_prefix(query, "event:props:")

    query_allowed? =
      case {prop_filter, property, allowed_props} do
        {_, _, :all} ->
          true

        {{"event:props:" <> prop, _}, _property, allowed_props} ->
          prop in allowed_props

        {_filter, "event:props:" <> prop, allowed_props} ->
          prop in allowed_props

        _ ->
          true
      end

    if query_allowed? do
      :ok
    else
      msg = "The owner of this site does not have access to the custom properties feature"
      {:error, {402, msg}}
    end
  end

  defp validate_metrics(metrics, property, query) do
    if length(metrics) == length(Enum.uniq(metrics)) do
      validate_each_metric(metrics, property, query)
    else
      {:error, "Metrics cannot be queried multiple times."}
    end
  end

  defp validate_each_metric(metrics, property, query) do
    Enum.reduce_while(metrics, [], fn metric, acc ->
      case validate_metric(metric, property, query) do
        {:ok, metric} -> {:cont, acc ++ [metric]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_metric("conversion_rate" = metric, property, query) do
    cond do
      property == "event:goal" ->
        {:ok, metric}

      query.filters["event:goal"] ->
        {:ok, metric}

      true ->
        {:error,
         "Metric `#{metric}` can only be queried in a goal breakdown or with a goal filter"}
    end
  end

  defp validate_metric("events" = metric, _, query) do
    if query.include_imported do
      {:error, "Metric `#{metric}` cannot be queried with imported data"}
    else
      {:ok, metric}
    end
  end

  defp validate_metric(metric, _, _) when metric in ["visitors", "pageviews"] do
    {:ok, metric}
  end

  defp validate_metric("views_per_visit" = metric, property, query) do
    cond do
      query.filters["event:page"] ->
        {:error, "Metric `#{metric}` cannot be queried with a filter on `event:page`."}

      property != nil ->
        {:error, "Metric `#{metric}` is not supported in breakdown queries."}

      true ->
        validate_session_metric(metric, property, query)
    end
  end

  defp validate_metric(metric, property, query)
       when metric in ["visits", "bounce_rate", "visit_duration"] do
    validate_session_metric(metric, property, query)
  end

  defp validate_metric(metric, _, _) do
    {:error,
     "The metric `#{metric}` is not recognized. Find valid metrics from the documentation: https://plausible.io/docs/stats-api#metrics"}
  end

  defp validate_session_metric(metric, property, query) do
    cond do
      event_only_property?(property) ->
        {:error, "Session metric `#{metric}` cannot be queried for breakdown by `#{property}`."}

      event_only_filter = find_event_only_filter(query) ->
        {:error,
         "Session metric `#{metric}` cannot be queried when using a filter on `#{event_only_filter}`."}

      true ->
        {:ok, metric}
    end
  end

  defp find_event_only_filter(query) do
    Map.keys(query.filters) |> Enum.find(&event_only_property?/1)
  end

  defp event_only_property?("event:name"), do: true
  defp event_only_property?("event:page"), do: true
  defp event_only_property?("event:goal"), do: true
  defp event_only_property?("event:props:" <> _), do: true
  defp event_only_property?(_), do: false

  def timeseries(conn, params) do
    site = Repo.preload(conn.assigns.site, :owner)

    with :ok <- validate_period(params),
         :ok <- validate_date(params),
         :ok <- validate_interval(params),
         query <- Query.from(site, params),
         :ok <- validate_goal_filter(site, query.filters),
         {:ok, metrics} <- parse_and_validate_metrics(params, nil, query),
         :ok <- ensure_custom_props_access(site, query) do
      graph = Plausible.Stats.timeseries(site, query, metrics)

      json(conn, %{results: graph})
    else
      err_tuple -> send_json_error_response(conn, err_tuple)
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

  defp validate_goal_filter(site, %{"event:goal" => {_type, goal_filter}}) do
    configured_goals =
      Plausible.Goals.for_site(site)
      |> Enum.map(fn
        %{page_path: path} when is_binary(path) -> "Visit " <> path
        %{event_name: event_name} -> event_name
      end)

    goals_in_filter =
      List.wrap(goal_filter)
      |> Plausible.Stats.Filters.Utils.unwrap_goal_value()

    if found = Enum.find(goals_in_filter, &(&1 not in configured_goals)) do
      msg =
        goal_not_configured_message(found) <>
          "Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"

      {:error, msg}
    else
      :ok
    end
  end

  defp validate_goal_filter(_site, _filters), do: :ok

  defp goal_not_configured_message("Visit " <> page_path) do
    "The pageview goal for the pathname `#{page_path}` is not configured for this site. "
  end

  defp goal_not_configured_message(goal) do
    "The goal `#{goal}` is not configured for this site. "
  end

  defp send_json_error_response(conn, {:error, {status, msg}}) do
    conn
    |> put_status(status)
    |> json(%{error: msg})
  end

  defp send_json_error_response(conn, {:error, msg}) do
    conn
    |> put_status(400)
    |> json(%{error: msg})
  end
end
