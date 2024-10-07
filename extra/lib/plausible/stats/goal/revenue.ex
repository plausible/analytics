defmodule Plausible.Stats.Goal.Revenue do
  @moduledoc """
  Revenue specific functions for the stats scope
  """
  import Ecto.Query

  alias Plausible.Stats.Filters

  @revenue_metrics [:average_revenue, :total_revenue]

  def revenue_metrics() do
    @revenue_metrics
  end

  def preload_revenue_currencies(site, goals, metrics, goal_filters?) do
    if requested?(metrics) and length(goals) > 0 and revenue_goals_available?(site) do
      goal_currency_map =
        Map.new(goals, fn goal -> {Plausible.Goal.display_name(goal), goal.currency} end)

      currencies = goal_currency_map |> Map.values() |> Enum.uniq()

      default_currency =
        if(goal_filters? and length(currencies) == 1, do: hd(currencies), else: nil)

      Map.put(goal_currency_map, :default, default_currency)
    else
      %{}
    end
  end

  def format_revenue_metric(value, query, dimension_values) do
    currency =
      query.revenue_currencies[:default] ||
        get_goal_dimension_revenue_currency(query, dimension_values)

    if currency do
      Money.new!(value, currency)
    else
      value
    end
  end

  defp revenue_goals_available?(site) do
    site = Plausible.Repo.preload(site, :owner)
    Plausible.Billing.Feature.RevenueGoals.check_availability(site.owner) == :ok
  end

  # :NOTE: Legacy queries don't have metrics associated with them so work around the issue by assuming
  #   revenue metric was requested.
  defp requested?([]), do: true
  defp requested?(metrics), do: Enum.any?(metrics, &(&1 in @revenue_metrics))

  defp get_goal_dimension_revenue_currency(query, dimension_values) do
    Enum.zip(query.dimensions, dimension_values)
    |> Enum.find_value(fn
      {"event:goal", goal_label} -> Map.get(query.revenue_currencies, goal_label)
      _ -> nil
    end)
  end

  @spec get_revenue_tracking_currency(Plausible.Site.t(), Plausible.Stats.Query.t(), [atom()]) ::
          {atom() | nil, [atom()]}
  @doc """
  Returns the common currency for the goal filters in a query. If there are no
  goal filters, multiple currencies or the site owner does not have access to
  revenue goals, `nil` is returned and revenue metrics are dropped.

  Aggregating revenue data works only for same currency goals. If the query is
  filtered by goals with different currencies, for example, one USD and other
  EUR, revenue metrics are dropped.
  """
  def get_revenue_tracking_currency(site, query, metrics) do
    goal_filters =
      case Filters.get_toplevel_filter(query, "event:goal") do
        [:is, "event:goal", list] -> list
        _ -> []
      end

    requested_revenue_metrics? = Enum.any?(metrics, &(&1 in @revenue_metrics))
    filtering_by_goal? = Enum.any?(goal_filters)

    if requested_revenue_metrics? && filtering_by_goal? && revenue_goals_available?(site) do
      revenue_goals_currencies =
        Plausible.Repo.all(
          from rg in Ecto.assoc(site, :revenue_goals),
            where: rg.display_name in ^goal_filters,
            select: rg.currency,
            distinct: true
        )

      if length(revenue_goals_currencies) == 1,
        do: {List.first(revenue_goals_currencies), metrics},
        else: {nil, metrics -- @revenue_metrics}
    else
      {nil, metrics -- @revenue_metrics}
    end
  end

  def cast_revenue_metrics_to_money([%{goal: _goal} | _rest] = results, revenue_goals)
      when is_list(revenue_goals) do
    for result <- results do
      if matching_goal = Enum.find(revenue_goals, &(&1.display_name == result.goal)) do
        cast_revenue_metrics_to_money(result, matching_goal.currency)
      else
        result
      end
    end
  end

  def cast_revenue_metrics_to_money(results, currency) when is_map(results) do
    for {metric, value} <- results, into: %{} do
      {metric, maybe_cast_metric_to_money(value, metric, currency)}
    end
  end

  def cast_revenue_metrics_to_money(results, _), do: results

  # :TODO: Avoid double-casting while working on the feature.
  def maybe_cast_metric_to_money(%Money{} = value, _, _), do: value

  def maybe_cast_metric_to_money(value, metric, currency) do
    if currency && metric in @revenue_metrics do
      Money.new!(value || 0, currency)
    else
      value
    end
  end
end
