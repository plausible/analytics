defmodule Plausible.Stats.Goal.Revenue do
  @moduledoc """
  Revenue specific functions for the stats scope
  """
  import Ecto.Query

  @revenue_metrics [:average_revenue, :total_revenue]

  def revenue_metrics() do
    @revenue_metrics
  end

  def total_revenue_query(query) do
    from(e in query,
      select_merge: %{
        total_revenue:
          fragment("toDecimal64(sum(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
      }
    )
  end

  def average_revenue_query(query) do
    from(e in query,
      select_merge: %{
        average_revenue:
          fragment("toDecimal64(avg(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
      }
    )
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
      case query.filters do
        %{"event:goal" => {:is, {_, goal_name}}} -> [goal_name]
        %{"event:goal" => {:member, list}} -> Enum.map(list, fn {_, goal_name} -> goal_name end)
        _any -> []
      end

    requested_revenue_metrics? = Enum.any?(metrics, &(&1 in @revenue_metrics))
    filtering_by_goal? = Enum.any?(goal_filters)

    revenue_goals_available? = fn ->
      site = Plausible.Repo.preload(site, :owner)
      Plausible.Billing.Feature.RevenueGoals.check_availability(site.owner) == :ok
    end

    if requested_revenue_metrics? && filtering_by_goal? && revenue_goals_available?.() do
      revenue_goals_currencies =
        Plausible.Repo.all(
          from rg in Ecto.assoc(site, :revenue_goals),
            where: rg.event_name in ^goal_filters,
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
      if matching_goal = Enum.find(revenue_goals, &(&1.event_name == result.goal)) do
        cast_revenue_metrics_to_money(result, matching_goal.currency)
      else
        result
      end
    end
  end

  def cast_revenue_metrics_to_money(results, currency) when is_map(results) do
    for {metric, value} <- results, into: %{} do
      if metric in @revenue_metrics && currency do
        {metric, Money.new!(value || 0, currency)}
      else
        {metric, value}
      end
    end
  end

  def cast_revenue_metrics_to_money(results, _), do: results
end
