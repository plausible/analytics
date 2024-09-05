defmodule PlausibleWeb.Api.GraphController do
  use PlausibleWeb, :controller

  alias Plausible.Stats
  alias Plausible.Stats.{Query, Comparisons, DateTimeRange}

  def graph(conn, params) do
    site = conn.assigns[:site]

    params = Map.put(params, "site_id", to_string(site.id))

    case Query.build(site, :internal, params, debug_metadata(conn)) do
      {:ok, query} ->
        [metric] = query.metrics
        {timeseries_result, _} = Stats.Timeseries.timeseries(site, query)

        comparison_result = get_comparison_result(site, query, Map.get(params, "comparison_params"))

        time_labels = label_timeseries(timeseries_result, comparison_result)
        present_index = present_index_for(site, query, time_labels)
        full_intervals = build_full_intervals(query, time_labels)

        json(conn, %{
          metric: metric,
          plot: plot_timeseries(timeseries_result, metric),
          labels: time_labels,
          comparison_plot: comparison_result && plot_timeseries(comparison_result, metric),
          comparison_labels: comparison_result && label_timeseries(comparison_result, nil),
          present_index: present_index,
          full_intervals: full_intervals
        })

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(message)
        |> halt()
    end
  end

  defp get_comparison_result(_site, _query, nil), do: nil

  defp get_comparison_result(site, query, %{} = comparison_params) do
    with {comparison_mode, comparison_opts} = parse_comparison_params(comparison_params),
          {:ok, comparison_query} <- Comparisons.compare(site, query, comparison_mode, comparison_opts) do
      Stats.Timeseries.timeseries(site, comparison_query) |> elem(0)
    else
      _ -> nil
    end
  end

  defp plot_timeseries(results, metric) do
    Enum.map(results, fn row ->
      case row[metric] do
        nil -> 0
        %Money{} = money -> Decimal.to_float(money.amount)
        value -> value
      end
    end)
  end

  defp label_timeseries(main_result, nil) do
    Enum.map(main_result, & &1.date)
  end

  @blank_value "__blank__"
  defp label_timeseries(main_result, comparison_result) do
    blanks_to_fill = Enum.count(comparison_result) - Enum.count(main_result)

    if blanks_to_fill > 0 do
      blanks = List.duplicate(@blank_value, blanks_to_fill)
      Enum.map(main_result, & &1.date) ++ blanks
    else
      Enum.map(main_result, & &1.date)
    end
  end

  defp present_index_for(site, query, time_labels) do
    now = DateTime.now!(site.timezone)
    ["time:" <> interval] = query.dimensions

    current_time_label =
      case interval do
        "hour" -> Calendar.strftime(now, "%Y-%m-%d %H:00:00")
        "day" -> DateTime.to_date(now) |> Date.to_string()
        "week" -> DateTime.to_date(now) |> date_or_weekstart(query) |> Date.to_string()
        "month" -> DateTime.to_date(now) |> Date.beginning_of_month() |> Date.to_string()
        "minute" -> Calendar.strftime(now, "%Y-%m-%d %H:%M:00")
      end

    Enum.find_index(time_labels, &(&1 == current_time_label))
  end

  defp build_full_intervals(%{dimensions: ["time:week"], date_range: date_range}, labels) do
    date_range = DateTimeRange.to_date_range(date_range)
    build_intervals(labels, date_range, &Date.beginning_of_week/1, &Date.end_of_week/1)
  end

  defp build_full_intervals(%{dimensions: ["time:month"], date_range: date_range}, labels) do
    date_range = DateTimeRange.to_date_range(date_range)
    build_intervals(labels, date_range, &Date.beginning_of_month/1, &Date.end_of_month/1)
  end

  defp build_full_intervals(_query, _labels) do
    nil
  end

  def build_intervals(labels, date_range, start_fn, end_fn) do
    for label <- labels, into: %{} do
      case Date.from_iso8601(label) do
        {:ok, date} ->
          interval_start = start_fn.(date)
          interval_end = end_fn.(date)

          within_interval? =
            Enum.member?(date_range, interval_start) && Enum.member?(date_range, interval_end)

          {label, within_interval?}

        _ ->
          {label, false}
      end
    end
  end

  defp date_or_weekstart(date, query) do
    weekstart = Date.beginning_of_week(date)

    date_range = DateTimeRange.to_date_range(query.date_range)

    if Enum.member?(date_range, weekstart) do
      weekstart
    else
      date
    end
  end

  defp parse_comparison_params(params) do
    options = [
      from: params["from"],
      to: params["to"],
      match_day_of_week?: params["match_day_of_week"]
    ]

    {params["mode"], options}
  end
end
