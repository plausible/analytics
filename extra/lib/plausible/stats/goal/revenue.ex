defmodule Plausible.Stats.Goal.Revenue do
  @moduledoc """
  Revenue specific functions for the stats scope
  """

  @revenue_metrics [:average_revenue, :total_revenue]

  def revenue_metrics() do
    @revenue_metrics
  end

  @doc """
  Preloads revenue currencies for a query. Used when parsing the query.

  Returns tuple containing revenue warning (if set, no revenue metrics should be calculated) and
  revenue currencies map.

  Assumptions and business logic:
  1. Goals are already filtered according to query filters and dimensions
  2. If there's a single currency involved, return map containing the default
  3. If there's a breakdown by event:goal we return all the relevant currencies as a map
  4. If filtering by multiple different currencies without event:goal breakdown empty map is returned
  5. If user has no access or preloading is not needed, empty map is returned

  The resulting data structure is attached to a `Query` and used below in `format_revenue_metric/3`.
  """
  def preload(site, goals, metrics, dimensions) do
    cond do
      not requested?(metrics) -> {nil, %{}}
      not available?(site) -> {:revenue_goals_unavailable, %{}}
      true -> preload(goals, dimensions)
    end
  end

  defp preload(goals, dimensions) do
    goal_currency_map =
      goals
      |> Map.new(fn goal -> {Plausible.Goal.display_name(goal), goal.currency} end)
      |> Map.reject(fn {_goal, currency} -> is_nil(currency) end)

    currencies = goal_currency_map |> Map.values() |> Enum.uniq()
    goal_dimension? = "event:goal" in dimensions

    case {currencies, goal_dimension?} do
      {[currency], false} -> {nil, %{default: currency}}
      {[], _} -> {:no_revenue_goals_matching, %{}}
      {_, true} -> {nil, goal_currency_map}
      _ -> {:no_single_revenue_currency, %{}}
    end
  end

  def format_revenue_metric(_, query, _) when not is_nil(query.revenue_warning), do: nil

  def format_revenue_metric(value, query, dimension_values) do
    currency =
      query.revenue_currencies[:default] ||
        get_goal_dimension_revenue_currency(query, dimension_values)

    if currency do
      money = Money.new!(value || 0, currency)

      %{
        short: Money.to_string!(money, format: :short, fractional_digits: 1),
        long: Money.to_string!(money),
        value: Decimal.to_float(money.amount),
        currency: currency
      }
    else
      value
    end
  end

  def available?(site) do
    site = Plausible.Repo.preload(site, :team)
    Plausible.Billing.Feature.RevenueGoals.check_availability(site.team) == :ok
  end

  # :NOTE: Legacy queries don't have metrics associated with them so work around the issue by assuming
  #   revenue metric was requested.
  def requested?([]), do: true
  def requested?(metrics), do: Enum.any?(metrics, &(&1 in @revenue_metrics))

  defp get_goal_dimension_revenue_currency(query, dimension_values) do
    Enum.zip(query.dimensions, dimension_values)
    |> Enum.find_value(fn
      {"event:goal", goal_label} -> Map.get(query.revenue_currencies, goal_label)
      _ -> nil
    end)
  end
end
