defmodule Plausible.Stats.Breakdown do
  @moduledoc """
  Builds breakdown results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  alias Plausible.Stats.{Query, QueryRunner, QueryOptimizer, Comparisons}

  def breakdown(
        site,
        %Query{dimensions: [dimension], order_by: order_by} = query,
        metrics,
        {limit, page},
        _opts \\ []
      ) do
    transformed_metrics = transform_metrics(metrics, dimension)
    transformed_order_by = transform_order_by(order_by || [], dimension)

    query_with_metrics =
      query
      |> Query.set(
        metrics: transformed_metrics,
        # Concat client requested order with default order, overriding only if client explicitly requests it
        order_by:
          Enum.concat(transformed_order_by, infer_order_by(transformed_metrics, dimension))
          |> Enum.uniq_by(&elem(&1, 0)),
        dimensions: transform_dimensions(dimension),
        filters: query.filters ++ dimension_filters(dimension),
        pagination: %{limit: limit, offset: (page - 1) * limit},
        # Allow pageview and event metrics to be queried off of sessions table
        legacy_breakdown: true
      )
      |> QueryOptimizer.optimize()

    QueryRunner.run(site, query_with_metrics)
    |> build_breakdown_result(query_with_metrics, metrics)
  end

  def formatted_date_ranges(query) do
    formatted = %{
      date_range_label: format_date_range(query)
    }

    if query.include.comparisons do
      comparison_date_range_label =
        query
        |> Comparisons.get_comparison_query(query.include.comparisons)
        |> format_date_range()

      Map.put(
        formatted,
        :comparison_date_range_label,
        comparison_date_range_label
      )
    else
      formatted
    end
  end

  defp build_breakdown_result(query_result, query, metrics) do
    dimension_keys = query.dimensions |> Enum.map(&result_key/1)

    query_result.results
    |> Enum.map(fn entry ->
      comparison_map =
        if entry[:comparison] do
          comparison =
            build_map(metrics, entry.comparison.metrics)
            |> Map.put(:change, build_map(metrics, entry.comparison.change))

          %{comparison: comparison}
        else
          %{}
        end

      build_map(dimension_keys, entry.dimensions)
      |> Map.merge(build_map(metrics, entry.metrics))
      |> Map.merge(comparison_map)
    end)
  end

  defp build_map(keys, values) do
    Enum.zip(keys, values) |> Map.new()
  end

  defp result_key("event:props:" <> custom_property), do: custom_property
  defp result_key("event:" <> key), do: key |> String.to_existing_atom()
  defp result_key("visit:" <> key), do: key |> String.to_existing_atom()
  defp result_key(dimension), do: dimension

  defp maybe_remap_to_group_conversion_rate(metric, dimension) do
    case {metric, dimension} do
      {:conversion_rate, "event:props:" <> _} -> :conversion_rate
      {:conversion_rate, "event:goal"} -> :conversion_rate
      {:conversion_rate, _} -> :group_conversion_rate
      _ -> metric
    end
  end

  defp transform_metrics(metrics, dimension) do
    metrics =
      if is_nil(metric_to_order_by(metrics)) do
        metrics ++ [:visitors]
      else
        metrics
      end

    Enum.map(metrics, fn metric -> maybe_remap_to_group_conversion_rate(metric, dimension) end)
  end

  defp transform_order_by(order_by, dimension) do
    Enum.map(order_by, fn {metric, direction} ->
      {maybe_remap_to_group_conversion_rate(metric, dimension), direction}
    end)
  end

  defp infer_order_by(metrics, "event:goal"),
    do: [{metric_to_order_by(metrics), :desc}]

  defp infer_order_by(metrics, dimension),
    do: [{metric_to_order_by(metrics), :desc}, {dimension, :asc}]

  defp metric_to_order_by(metrics) do
    Enum.find(metrics, &(&1 != :time_on_page))
  end

  def transform_dimensions("visit:browser_version"),
    do: ["visit:browser", "visit:browser_version"]

  def transform_dimensions("visit:os_version"), do: ["visit:os", "visit:os_version"]
  def transform_dimensions(dimension), do: [dimension]

  @filter_dimensions_not %{
    "visit:city" => [0],
    "visit:country" => ["\0\0", "ZZ"],
    "visit:region" => [""],
    "visit:utm_medium" => [""],
    "visit:utm_source" => [""],
    "visit:utm_campaign" => [""],
    "visit:utm_content" => [""],
    "visit:utm_term" => [""],
    "visit:entry_page" => [""],
    "visit:exit_page" => [""]
  }

  @extra_filter_dimensions Map.keys(@filter_dimensions_not)

  defp dimension_filters(dimension) when dimension in @extra_filter_dimensions do
    [[:is_not, dimension, Map.get(@filter_dimensions_not, dimension)]]
  end

  defp dimension_filters(_), do: []

  defp format_date_range(%Query{} = query) do
    year = query.now.year
    %Date.Range{first: first, last: last} = Query.date_range(query, trim_trailing: true)

    cond do
      first == last ->
        strfdate(first, first.year != year)

      first.year == last.year ->
        "#{strfdate(first, false)} - #{strfdate(last, year != last.year)}"

      true ->
        "#{strfdate(first, true)} - #{strfdate(last, true)}"
    end
  end

  defp strfdate(date, true = _include_year) do
    Calendar.strftime(date, "%-d %b %Y")
  end

  defp strfdate(date, false = _include_year) do
    Calendar.strftime(date, "%-d %b")
  end
end
