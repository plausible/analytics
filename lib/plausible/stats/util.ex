defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  import Ecto.Query

  @doc """
  Drops all the atom keys starting with two underscores.

  Currently private fields are:
    * `__internal_visits` is fetched when querying bounce rate and visit duration, as it
       is needed to calculate these from imported data. This function removes that metric
       from all entries in the results list.
    * `__events_pageviews` is calculated for sessions when it's the event pageviews
      (and not session pageviews) that need to be summed in breakdowns.
  """
  def drop_internal_keys(results) when is_list(results) do
    Enum.map(results, &drop_internal_keys/1)
  end

  def drop_internal_keys(result) when is_map(result) do
    Enum.reject(result, fn {key, _value} when is_atom(key) ->
      key
      |> Atom.to_string()
      |> String.starts_with?("__")
    end)
    |> Enum.into(%{})
  end

  @revenue_metrics [:average_revenue, :total_revenue]

  @spec get_revenue_tracking_currency(Plausible.Site.t(), Plausible.Stats.Query.t(), [atom()]) ::
          {atom() | nil, [atom()]}
  @doc """
  Returns the common currency for the goal filters in a query. If there are no
  goal filters, or multiple currencies, `nil` is returned and revenue metrics
  are dropped.

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

    if Enum.any?(metrics, &(&1 in @revenue_metrics)) && Enum.any?(goal_filters) do
      revenue_goals_currencies =
        Plausible.Repo.all(
          from(rg in Ecto.assoc(site, :revenue_goals),
            where: rg.event_name in ^goal_filters,
            select: rg.currency,
            distinct: true
          )
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
