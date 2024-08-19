defmodule Plausible.Stats.Breakdown do
  @moduledoc """
  Builds breakdown results for v1 of our stats API and dashboards.

  Avoid adding new logic here - update QueryBuilder etc instead.
  """

  use Plausible.ClickhouseRepo
  use Plausible
  use Plausible.Stats.SQL.Fragments

  import Plausible.Stats.Base
  import Ecto.Query
  alias Plausible.Stats.{Query, QueryOptimizer, QueryResult, SQL}

  def breakdown(site, %Query{dimensions: [dimension]} = query, metrics, pagination, _opts \\ []) do
    transformed_metrics = transform_metrics(metrics, dimension)

    query_with_metrics =
      Query.set(
        query,
        metrics: transformed_metrics,
        order_by: infer_order_by(transformed_metrics, dimension),
        dimensions: transform_dimensions(dimension),
        filters: query.filters ++ dimension_filters(dimension),
        v2: true,
        # Allow pageview and event metrics to be queried off of sessions table
        legacy_breakdown: true
      )
      |> QueryOptimizer.optimize()

    q = SQL.QueryBuilder.build(query_with_metrics, site)

    q
    |> apply_pagination(pagination)
    |> ClickhouseRepo.all(query: query)
    |> QueryResult.from(query_with_metrics)
    |> build_breakdown_result(query_with_metrics, metrics)
    |> maybe_add_time_on_page(site, query_with_metrics, metrics)
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

  defp maybe_add_time_on_page(event_results, site, query, metrics) do
    if query.dimensions == ["event:page"] and :time_on_page in metrics do
      pages = Enum.map(event_results, & &1[:page])
      time_on_page_result = breakdown_time_on_page(site, query, pages)

      event_results
      |> Enum.map(fn row ->
        Map.put(row, :time_on_page, time_on_page_result[row[:page]])
      end)
    else
      event_results
    end
  end

  defp breakdown_time_on_page(_site, _query, []) do
    %{}
  end

  defp breakdown_time_on_page(site, query, pages) do
    import Ecto.Query

    windowed_pages_q =
      from e in base_event_query(site, Query.remove_filters(query, ["event:page", "event:props"])),
        select: %{
          next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :event_horizon),
          next_pathname: over(fragment("leadInFrame(?)", e.pathname), :event_horizon),
          timestamp: e.timestamp,
          pathname: e.pathname,
          session_id: e.session_id
        },
        windows: [
          event_horizon: [
            partition_by: e.session_id,
            order_by: e.timestamp,
            frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
          ]
        ]

    timed_page_transitions_q =
      from e in subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: e.pathname in ^pages,
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }

    no_select_timed_pages_q =
      from e in subquery(timed_page_transitions_q),
        group_by: e.pathname

    timed_pages_q =
      if query.include_imported do
        # Imported page views have pre-calculated values
        imported_timed_pages_q =
          from i in "imported_pages",
            group_by: i.page,
            where: i.site_id == ^site.id,
            where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
            where: i.page in ^pages,
            select: %{
              page: i.page,
              time_on_page: sum(i.time_on_page),
              visits: sum(i.pageviews) - sum(i.exits)
            }

        timed_pages_q =
          from e in no_select_timed_pages_q,
            select: %{
              page: e.pathname,
              time_on_page: sum(e.duration),
              visits: fragment("countIf(?)", e.transition)
            }

        "timed_pages"
        |> with_cte("timed_pages", as: ^timed_pages_q)
        |> with_cte("imported_timed_pages", as: ^imported_timed_pages_q)
        |> join(:full, [t], i in "imported_timed_pages", on: t.page == i.page)
        |> select(
          [t, i],
          {
            fragment("if(empty(?),?,?)", t.page, i.page, t.page),
            (t.time_on_page + i.time_on_page) / (t.visits + i.visits)
          }
        )
      else
        from e in no_select_timed_pages_q,
          select: {e.pathname, fragment("sum(?)/countIf(?)", e.duration, e.transition)}
      end

    timed_pages_q
    |> Plausible.ClickhouseRepo.all(query: query)
    |> Map.new()
  end

  defp transform_metrics(metrics, dimension) do
    metrics =
      if is_nil(metric_to_order_by(metrics)) do
        metrics ++ [:visitors]
      else
        metrics
      end

    Enum.map(metrics, fn metric ->
      case {metric, dimension} do
        {:conversion_rate, "event:props:" <> _} -> :conversion_rate
        {:conversion_rate, "event:goal"} -> :conversion_rate
        {:conversion_rate, _} -> :group_conversion_rate
        _ -> metric
      end
    end)
  end

  defp infer_order_by(metrics, "event:goal"), do: [{metric_to_order_by(metrics), :desc}]

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

  defp apply_pagination(q, {limit, page}) do
    offset = (page - 1) * limit

    q
    |> limit(^limit)
    |> offset(^offset)
  end

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
