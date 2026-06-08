defmodule Plausible.Stats.Dashboard.CsvExport do
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
    "cities.csv"
  ]

  def get_csvs(site, params, debug_metadata) do
    with {:ok, queries_by_filename} <- create_queries_by_filename(site, params, debug_metadata) do
      csv_values =
        queries_by_filename
        |> Enum.map(fn {filename, query} ->
          fn -> run_query_into_csv(site, filename, query) end
        end)
        |> Plausible.ClickhouseRepo.parallel_tasks()

      csvs =
        queries_by_filename
        |> Enum.map(fn {filename, _query} -> filename end)
        |> Enum.zip(csv_values)
        |> Enum.map(fn {k, v} -> {String.to_charlist(k), IO.iodata_to_binary(v)} end)

      {:ok, csvs}
    end
  end

  defp create_queries_by_filename(site, params, debug_metadata) do
    # TODO: Iterate over all @csv_filenames once all FE reports have been migrated.
    requested = Map.keys(params["reports"] || %{}) |> Enum.filter(&(&1 in @csv_filenames))

    Enum.reduce_while(requested, {:ok, []}, fn filename, acc ->
      case parse_csv_query(site, filename, params, debug_metadata) do
        {:ok, query} -> {:cont, {:ok, elem(acc, 1) ++ [{filename, query}]}}
        error_tuple -> {:halt, error_tuple}
      end
    end)
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
    order_by = [{:visitors, :desc} | Enum.map(query.dimensions, &{&1, :asc})]

    query =
      query
      |> Query.set(order_by: order_by)
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
end
