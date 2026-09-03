defmodule Plausible.Stats.Funnel do
  @moduledoc """
  Module responsible for funnel evaluation, i.e. building and executing
  ClickHouse funnel query based on `Plausible.Funnel` definition.
  """

  @funnel_window_duration 86_400

  alias Plausible.Funnel
  alias Plausible.Funnels

  import Ecto.Query
  import Plausible.Stats.SQL.Fragments
  import Plausible.Stats.Util, only: [percentage: 2]

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.{Base, Comparisons, DateTimeRange, Query}
  alias Plausible.Stats.Goal.Revenue

  @spec funnel(Plausible.Site.t(), Plausible.Stats.Query.t(), Funnel.t() | pos_integer()) ::
          {:ok, map()} | {:error, :funnel_not_found}
  def funnel(site, query, funnel_id) when is_integer(funnel_id) do
    case Funnels.get(site.id, funnel_id) do
      %Funnel{} = funnel ->
        funnel(site, query, funnel)

      nil ->
        {:error, :funnel_not_found}
    end
  end

  def funnel(site, query, %Funnel{} = funnel) do
    revenue_steps = revenue_steps(site, funnel)

    comparison =
      if query.comparison_utc_time_range do
        query
        |> Comparisons.get_comparison_query()
        |> compute(funnel, revenue_steps)
      end

    {:ok,
     query
     |> compute(funnel, revenue_steps)
     |> Map.merge(%{
       name: funnel.name,
       strict_order: funnel.strict_order,
       comparison: comparison,
       date_range: tz_date_range(query.utc_time_range, query.timezone),
       comparison_date_range:
         if(query.comparison_utc_time_range,
           do: tz_date_range(query.comparison_utc_time_range, query.timezone)
         )
     })}
  end

  defp revenue_steps(site, funnel) do
    if Revenue.available?(site) do
      Enum.filter(funnel.steps, fn step ->
        match?(%Plausible.Goal{currency: currency} when not is_nil(currency), step.goal)
      end)
    else
      []
    end
  end

  defp compute(query, funnel, revenue_steps) do
    goals = Enum.map(funnel.steps, & &1.goal)

    funnel_data =
      query
      |> Query.set(preloaded_goals: %{all: [], matching_toplevel_filters: goals})
      |> Base.base_event_query()
      |> funnel_query(funnel, revenue_steps)
      # We pass the query struct to record query metadata for
      # the CH debug console.
      |> ClickhouseRepo.all(query: query)

    visitors_by_step = Map.new(funnel_data, &{&1.step, &1.visitors})

    # Funnel definition steps are 1-indexed, if there's index 0 in the resulting query,
    # it signifies the number of visitors that haven't entered the funnel.
    not_entering_visitors = Map.get(visitors_by_step, 0, 0)

    all_visitors = funnel_data |> Enum.map(& &1.visitors) |> Enum.sum()

    steps =
      backfill_steps(visitors_by_step, revenue_totals(funnel_data, revenue_steps), funnel)

    visitors_at_first_step = List.first(steps).visitors

    %{
      steps: steps,
      all_visitors: all_visitors,
      entering_visitors: visitors_at_first_step,
      entering_visitors_percentage: percentage(visitors_at_first_step, all_visitors),
      never_entering_visitors: all_visitors - visitors_at_first_step,
      never_entering_visitors_percentage: percentage(not_entering_visitors, all_visitors)
    }
  end

  defp funnel_query(query, funnel_definition, revenue_steps) do
    q_events =
      from(e in query,
        select: %{user_id: e.user_id, _sample_factor: fragment("any(_sample_factor)")},
        where: e.site_id == ^funnel_definition.site_id,
        group_by: e.user_id,
        order_by: [desc: fragment("step")]
      )
      |> select_funnel(funnel_definition)
      |> select_user_revenue(revenue_steps)

    from(f in subquery(q_events),
      select: %{step: f.step, visitors: total()},
      group_by: f.step
    )
    |> select_revenue_totals(revenue_steps)
  end

  defp select_user_revenue(db_query, revenue_steps) do
    sums =
      Map.new(revenue_steps, fn step ->
        goal_condition = Plausible.Stats.Goals.goal_condition(step.goal)

        {revenue_key(step),
         dynamic([e], fragment("sumIf(?, ?)", e.revenue_reporting_amount, ^goal_condition))}
      end)

    select_merge_dynamics(db_query, sums)
  end

  defp select_revenue_totals(db_query, revenue_steps) do
    totals =
      Map.new(revenue_steps, fn step ->
        key = revenue_key(step)

        {key,
         dynamic(
           [f],
           fragment("toDecimal64(sum(?) * any(_sample_factor), 3)", field(f, ^key))
         )}
      end)

    select_merge_dynamics(db_query, totals)
  end

  defp select_merge_dynamics(db_query, dynamics) when map_size(dynamics) == 0, do: db_query

  defp select_merge_dynamics(db_query, dynamics) do
    from(q in db_query, select_merge: ^dynamics)
  end

  defp revenue_key(%{step_order: step_order}), do: :"revenue_#{step_order}"

  # The per-user sum runs for every buyer, even one that a strict order scored
  # below the step that holds their purchase. Such a buyer did not reach the step,
  # so the filter leaves their money out.
  defp revenue_totals(funnel_data, revenue_steps) do
    Map.new(revenue_steps, fn step ->
      key = revenue_key(step)

      total =
        funnel_data
        |> Enum.filter(&(&1.step >= step.step_order))
        |> Enum.reduce(Decimal.new(0), fn row, acc ->
          Decimal.add(acc, Map.get(row, key) || 0)
        end)

      {step.step_order, total}
    end)
  end

  defp select_funnel(db_query, funnel_definition) do
    window_funnel_steps =
      Enum.reduce(funnel_definition.steps, nil, fn step, acc ->
        goal_condition = Plausible.Stats.Goals.goal_condition(step.goal)

        if acc do
          dynamic([q], fragment("?, ?", ^acc, ^goal_condition))
        else
          dynamic([q], fragment("?", ^goal_condition))
        end
      end)

    dynamic_window_funnel =
      if funnel_definition.strict_order do
        dynamic(
          [q],
          fragment(
            "windowFunnel(?, 'strict_order')(timestamp, ?)",
            @funnel_window_duration,
            ^window_funnel_steps
          )
        )
      else
        dynamic(
          [q],
          fragment("windowFunnel(?)(timestamp, ?)", @funnel_window_duration, ^window_funnel_steps)
        )
      end

    from(q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
    )
  end

  defp backfill_steps(visitors_by_step, revenue_by_step, funnel) do
    # Directly from ClickHouse we only get visitor counts per step index,
    # but no totals including previous steps are aggregated.
    # Hence we need to perform the appropriate backfill
    # and also calculate dropoff and conversion rate for each step.
    # In case ClickHouse returns 0-index funnel result, we're going to ignore it
    # anyway, since we fold over steps as per definition, that are always
    # indexed starting from 1.
    max_step = Enum.max_by(funnel.steps, & &1.step_order).step_order

    funnel
    |> Map.fetch!(:steps)
    |> Enum.reduce({nil, nil, []}, fn step, {total_visitors, visitors_at_previous, acc} ->
      # first step contains the total number of all visitors qualifying for the funnel,
      # with each subsequent step needing to accumulate sum of the previous one(s)
      visitors_at_step =
        step.step_order..max_step
        |> Enum.map(&Map.get(visitors_by_step, &1, 0))
        |> Enum.sum()

      # accumulate current_visitors for the next iteration
      current_visitors = visitors_at_step

      # First step contains the total number of visitors that we base percentage dropoff on
      total_visitors =
        total_visitors ||
          current_visitors

      # Dropoff is 0 for the first step, otherwise we subtract current from previous
      dropoff = if visitors_at_previous, do: visitors_at_previous - current_visitors, else: 0

      dropoff_percentage = percentage(dropoff, visitors_at_previous)
      conversion_rate = percentage(current_visitors, total_visitors)
      conversion_rate_step = percentage(current_visitors, visitors_at_previous)

      computed_step =
        %{
          dropoff: dropoff,
          dropoff_percentage: dropoff_percentage,
          conversion_rate: conversion_rate,
          conversion_rate_step: conversion_rate_step,
          visitors: visitors_at_step,
          label: to_string(step.goal)
        }
        |> Map.merge(revenue_metrics(step, revenue_by_step, visitors_at_step))

      {total_visitors, current_visitors, [computed_step | acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end

  defp revenue_metrics(step, revenue_by_step, visitors_at_step) do
    case Map.fetch(revenue_by_step, step.step_order) do
      {:ok, revenue} ->
        currency = step.goal.currency

        %{
          revenue: Revenue.format_revenue_metric(revenue, currency),
          revenue_per_visitor:
            Revenue.format_revenue_metric(per_visitor(revenue, visitors_at_step), currency)
        }

      :error ->
        %{}
    end
  end

  defp per_visitor(_revenue, 0), do: Decimal.new(0)
  defp per_visitor(revenue, visitors), do: revenue |> Decimal.div(visitors) |> Decimal.round(3)

  defp tz_date_range(utc_time_range, timezone) do
    range = DateTimeRange.to_date_range(utc_time_range, timezone)
    [range.first, range.last]
  end
end
