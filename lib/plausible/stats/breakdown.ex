defmodule Plausible.Stats.Breakdown do
  @moduledoc """
  Builds breakdown results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible
  use Plausible.Stats.SQL.Fragments

  alias Plausible.Stats.{Query, QueryOptimizer, QueryExecutor}

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
      Query.set(
        query,
        metrics: transformed_metrics,
        # Concat client requested order with default order, overriding only if client explicitly requests it
        order_by:
          Enum.concat(transformed_order_by, infer_order_by(transformed_metrics, dimension))
          |> Enum.uniq_by(&elem(&1, 0)),
        dimensions: transform_dimensions(dimension),
        filters: query.filters ++ dimension_filters(dimension),
        pagination: %{limit: limit, offset: (page - 1) * limit},
        v2: true,
        # Allow pageview and event metrics to be queried off of sessions table
        legacy_breakdown: true
      )
      |> QueryOptimizer.optimize()

    QueryExecutor.execute(site, query_with_metrics)
    |> build_breakdown_result(query_with_metrics, metrics)
    |> update_currency_metrics(site, query_with_metrics)
  end

  defp build_breakdown_result(query_result, query, metrics) do
    query_result.results
    |> Enum.map(fn %{dimensions: dimensions, metrics: entry_metrics} ->
      dimension_map =
        query.dimensions |> Enum.map(&result_key/1) |> Enum.zip(dimensions) |> Enum.into(%{})

      metrics_map = Enum.zip(metrics, entry_metrics) |> Enum.into(%{})

      Map.merge(dimension_map, metrics_map)
    end)
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

  on_ee do
    defp update_currency_metrics(results, site, %Query{dimensions: ["event:goal"]}) do
      site = Plausible.Repo.preload(site, :goals)

      {event_goals, _pageview_goals} = Enum.split_with(site.goals, & &1.event_name)
      revenue_goals = Enum.filter(event_goals, &Plausible.Goal.Revenue.revenue?/1)

      if length(revenue_goals) > 0 and Plausible.Billing.Feature.RevenueGoals.enabled?(site) do
        Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
      else
        remove_revenue_metrics(results)
      end
    end

    defp update_currency_metrics(results, site, query) do
      {currency, _metrics} =
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, query.metrics)

      if currency do
        results
        |> Enum.map(&Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(&1, currency))
      else
        remove_revenue_metrics(results)
      end
    end
  else
    defp update_currency_metrics(results, _site, _query), do: remove_revenue_metrics(results)
  end

  defp remove_revenue_metrics(results) do
    Enum.map(results, fn map ->
      map
      |> Map.delete(:total_revenue)
      |> Map.delete(:average_revenue)
    end)
  end
end
