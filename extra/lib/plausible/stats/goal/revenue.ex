defmodule Plausible.Stats.Goal.Revenue do
  @moduledoc """
  Revenue specific functions for the stats scope
  """

  @revenue_metrics [:average_revenue, :total_revenue]

  def revenue_metrics() do
    @revenue_metrics
  end

  def preload_revenue_currencies(site, goals, metrics, goal_filters?) do
    if requested?(metrics) and length(goals) > 0 and available?(site) do
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

  defp available?(site) do
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
end
