defmodule Plausible.Stats.Dashboard.CsvExport do
  @moduledoc false

  alias Plausible.Stats.Dashboard.QueryParser
  alias Plausible.Stats.{Time, ParsedQueryParams, Query, QueryBuilder, QueryRunner, QueryResult}

  @csv_filenames [
    "visitors.csv",
    "pages.csv",
    "entry_pages.csv",
    "exit_pages.csv",
    "browsers.csv",
    "browser_versions.csv",
    "operating_systems.csv",
    "operating_system_versions.csv",
    "devices.csv",
    "channels.csv",
    "sources.csv",
    "referrers.csv",
    "utm_mediums.csv",
    "utm_sources.csv",
    "utm_campaigns.csv",
    "utm_contents.csv",
    "utm_terms.csv",
    "countries.csv",
    "regions.csv",
    "cities.csv",
    "custom_props.csv",
    "conversions.csv"
  ]

  def get_csvs(site, params, debug_metadata) do
    with {:ok, tasks_by_filename} <- create_tasks_by_filename(site, params, debug_metadata) do
      csv_values =
        tasks_by_filename
        |> Enum.map(fn {_filename, task} -> task end)
        |> Plausible.ClickhouseRepo.parallel_tasks()

      csvs =
        tasks_by_filename
        |> Enum.map(fn {filename, _task} -> filename end)
        |> Enum.zip(csv_values)
        |> Enum.reject(fn {_filename, csv_values} -> is_nil(csv_values) end)
        |> Enum.map(fn {k, v} -> {String.to_charlist(k), IO.iodata_to_binary(v)} end)

      {:ok, csvs}
    end
  end

  defp create_tasks_by_filename(site, params, debug_metadata) do
    requested = Map.keys(params["reports"] || %{}) |> Enum.filter(&(&1 in @csv_filenames))

    Enum.reduce_while(requested, {:ok, []}, fn filename, acc ->
      case create_task(site, filename, params, debug_metadata) do
        {:ok, task} -> {:cont, {:ok, elem(acc, 1) ++ [{filename, task}]}}
        error_tuple -> {:halt, error_tuple}
      end
    end)
  end

  defp create_task(site, "custom_props.csv", params, debug_metadata) do
    with {:ok, prop_keys_query} <- get_custom_prop_key_query(site, params, debug_metadata),
         prop_keys = get_custom_prop_keys(site, prop_keys_query),
         {:ok, prop_value_queries_by_prop_key} <-
           get_custom_prop_queries(site, params, debug_metadata, prop_keys) do
      {:ok, fn -> get_custom_props_csv(site, prop_value_queries_by_prop_key) end}
    end
  end

  defp create_task(site, filename, params, debug_metadata) do
    with {:ok, query} <- parse_csv_query(site, filename, params, debug_metadata) do
      {:ok, fn -> run_query_into_csv(site, filename, query) end}
    end
  end

  defp parse_csv_query(site, filename, params, debug_metadata) do
    params = construct_raw_query_params(filename, params)

    with {:ok, %ParsedQueryParams{} = params} <- QueryParser.parse(params) do
      QueryBuilder.build(site, params, debug_metadata)
    end
  end

  defp construct_raw_query_params(filename, params) do
    report_params = params["reports"][filename]

    filters =
      case report_params["always_on_filters"] do
        always_on when is_list(always_on) -> params["filters"] ++ always_on
        _ -> params["filters"]
      end

    %{
      "dimensions" => report_params["dimensions"],
      "metrics" => report_params["metrics"],
      "date_range" => params["date_range"],
      "relative_date" => params["relative_date"],
      "filters" => filters,
      "include" => params["include"]
    }
  end

  defp run_query_into_csv(site, "visitors.csv", query) do
    query =
      query
      |> Query.set(order_by: [{Time.time_dimension(query), :asc}])
      |> Query.set_include(:time_labels, true)
      |> Query.set_include(:empty_metrics, true)

    QueryRunner.run(site, query) |> timeseries_query_result_to_csv()
  end

  defp run_query_into_csv(site, filename, query) do
    # The export is limited to 300 entries for other reports and 100 entries for
    # pages because bigger result sets start causing failures. Since we request
    # data like time on page or bounce_rate for pages in a separate query using
    # the IN filter, it causes the requests to balloon in payload size.
    limit = if filename in ["pages.csv", "exit_pages.csv"], do: 100, else: 300

    query =
      query
      |> Query.set(order_by: get_order_by(query.dimensions))
      |> Query.set(pagination: %{limit: limit, offset: 0})

    QueryRunner.run(site, query) |> query_result_to_csv()
  end

  defp query_result_to_csv(%QueryResult{results: results, query: query}) do
    results
    |> Enum.reduce([csv_first_row(query)], fn row, acc ->
      acc ++ [csv_dimension_values(query[:dimensions], row) ++ row.metrics]
    end)
    |> NimbleCSV.RFC4180.dump_to_iodata()
  end

  defp timeseries_query_result_to_csv(%QueryResult{results: results, query: query, meta: meta}) do
    meta[:time_labels]
    |> Enum.reduce([csv_first_row(query)], fn timelabel, acc ->
      if result_item = find_result_item_by_timelabel(results, timelabel) do
        acc ++ [[timelabel | result_item.metrics]]
      else
        acc ++ [[timelabel | meta[:empty_metrics]]]
      end
    end)
    |> NimbleCSV.RFC4180.dump_to_iodata()
  end

  defp find_result_item_by_timelabel(results, timelabel) do
    results
    |> Map.new(fn entry -> {Enum.at(entry.dimensions, 0), entry} end)
    |> Map.get(timelabel)
  end

  defp get_order_by(["event:goal"]), do: [{:visitors, :desc}]

  defp get_order_by(dimensions) do
    [{:visitors, :desc} | Enum.map(dimensions, &{&1, :asc})]
  end

  defp csv_first_row(query) do
    csv_dimension_labels(query[:dimensions]) ++ csv_metric_labels(query)
  end

  defp csv_dimension_labels(["time:" <> _]) do
    [:date]
  end

  defp csv_dimension_labels(["visit:browser_version", "visit:browser"]) do
    [:name, :version]
  end

  defp csv_dimension_labels(["visit:os_version", "visit:os"]) do
    [:name, :version]
  end

  defp csv_dimension_labels([_dimension]) do
    [:name]
  end

  defp get_goal_filtered_metric_label_overrides(query) do
    case query[:dimensions] do
      ["time:" <> _] ->
        %{
          visitors: :unique_conversions,
          events: :total_conversions,
          group_conversion_rate: :conversion_rate
        }

      ["event:goal"] ->
        %{
          visitors: :unique_conversions,
          events: :total_conversions
        }

      _ ->
        %{
          visitors: :conversions,
          group_conversion_rate: :conversion_rate
        }
    end
  end

  @dimension_specific_metric_label_overrides %{
    ["visit:entry_page"] => %{
      visitors: :unique_entrances,
      visits: :total_entrances
    },
    ["visit:exit_page"] => %{
      visitors: :unique_exits,
      visits: :total_exits
    },
    ["event:goal"] => %{
      visitors: :unique_conversions,
      events: :total_conversions
    }
  }

  defp csv_metric_labels(query) do
    goal_filter? =
      Enum.any?(query[:filters], fn [_operator, key | _rest] ->
        key == "event:goal"
      end)

    metric_label_overrides =
      if goal_filter? do
        get_goal_filtered_metric_label_overrides(query)
      else
        Map.get(@dimension_specific_metric_label_overrides, query[:dimensions], %{})
      end

    Enum.map(query[:metrics], &(metric_label_overrides[&1] || &1))
  end

  defp csv_dimension_values(["visit:browser_version", "visit:browser"], row) do
    row[:dimensions] |> Enum.reverse()
  end

  defp csv_dimension_values(["visit:os_version", "visit:os"], row) do
    row[:dimensions] |> Enum.reverse()
  end

  defp csv_dimension_values([_dimension], row) do
    row[:dimensions]
  end

  defp get_custom_prop_key_query(site, params, debug_metadata) do
    raw_params =
      construct_raw_query_params("custom_props.csv", params)
      |> Map.merge(%{
        "dimensions" => ["event:prop_key"],
        "metrics" => ["visitors"],
        "pagination" => %{"limit" => 25}
      })

    with {:ok, parsed} <- QueryParser.parse(raw_params),
         {:ok, query} <- QueryBuilder.build(site, parsed, debug_metadata) do
      {:ok, Query.set(query, order_by: [{:visitors, :desc}, {"event:prop_key", :asc}])}
    end
  end

  defp get_custom_prop_keys(site, query) do
    case Plausible.Stats.Filters.get_toplevel_filter(query, "event:props:") do
      [_op, "event:props:" <> key | _rest] ->
        [key]

      _ ->
        %QueryResult{results: results} = QueryRunner.run(site, query)

        Enum.map(results, fn r -> hd(r.dimensions) end)
        |> maybe_allowed_props_only(site)
    end
  end

  defp get_custom_prop_queries(site, params, debug_metadata, prop_keys) do
    Enum.reduce_while(prop_keys, {:ok, []}, fn prop_key, acc ->
      dimension = "event:props:#{prop_key}"

      raw_params =
        construct_raw_query_params("custom_props.csv", params)
        |> Map.put("dimensions", [dimension])

      with {:ok, parsed} <- QueryParser.parse(raw_params),
           {:ok, query} <- QueryBuilder.build(site, parsed, debug_metadata) do
        query =
          query
          |> Query.set(order_by: [{:visitors, :desc}, {dimension, :asc}])
          |> Query.set(pagination: %{limit: 300, offset: 0})

        {:cont, {:ok, elem(acc, 1) ++ [{prop_key, query}]}}
      else
        error_tuple -> {:halt, error_tuple}
      end
    end)
  end

  defp get_custom_props_csv(_site, []), do: nil

  defp get_custom_props_csv(site, prop_value_queries_by_prop_key) do
    [{_prop_key, %Query{metrics: metrics}} | _] = prop_value_queries_by_prop_key
    header_row = format_custom_props_header_row(metrics)
    data_rows = custom_prop_queries_into_data_rows(site, prop_value_queries_by_prop_key)

    NimbleCSV.RFC4180.dump_to_iodata([header_row] ++ data_rows)
  end

  defp custom_prop_queries_into_data_rows(site, prop_value_queries_by_prop_key) do
    prop_value_queries_by_prop_key
    |> Enum.map(fn {prop_key, query} ->
      fn ->
        %QueryResult{results: results} = QueryRunner.run(site, query)
        Enum.map(results, &format_custom_props_data_row(prop_key, &1))
      end
    end)
    |> Plausible.ClickhouseRepo.parallel_tasks()
    |> Enum.concat()
  end

  defp format_custom_props_header_row(metrics), do: [:property, :value] ++ metrics

  defp format_custom_props_data_row(prop_key, row),
    do: [prop_key | row.dimensions] ++ row.metrics

  defp maybe_allowed_props_only(prop_keys, site) do
    case Plausible.Props.allowed_for(site) do
      :all -> prop_keys
      allowed -> Enum.filter(prop_keys, &(&1 in allowed))
    end
  end
end
