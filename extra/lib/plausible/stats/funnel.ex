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
  alias Plausible.Stats.Exploration
  alias Plausible.Stats.Goal.Revenue

  @max_page_candidates 50

  @type candidate() :: %{step: map(), visitors: non_neg_integer()}

  @doc """
  Lists steps a funnel can be built from: all site goals, including
  ones with scroll threshold, custom props or revenue, along with the
  most visited pages and custom events not covered by a goal.

  Unlike exploration, candidates don't depend on any preceding steps,
  as funnel steps don't need to follow each other directly.
  """
  @spec candidates(Plausible.Site.t(), Query.t(), Keyword.t()) :: {:ok, [candidate()]}
  def candidates(site, query, opts \\ []) do
    search_term = opts |> Keyword.get(:search_term, "") |> String.trim()

    goals =
      site
      |> Plausible.Goals.for_site()
      |> Enum.filter(&matches_search?(&1, search_term))

    visitors_by_goal = goal_visitors(query, goals)

    goal_candidates =
      Enum.map(goals, fn goal ->
        %{step: goal_step(goal), visitors: Map.get(visitors_by_goal, goal.id, 0)}
      end)

    plain_goal_keys =
      goals
      |> Enum.filter(&plain_goal?/1)
      |> MapSet.new(&{&1.event_name || "pageview", &1.page_path || ""})

    {:ok, page_candidates} =
      Exploration.next_steps(site, query, [],
        search_term: search_term,
        include_goals?: false,
        max_candidates: @max_page_candidates
      )

    page_candidates =
      page_candidates
      |> Enum.reject(fn %{step: step} ->
        step.name == Exploration.Journey.Step.journey_end_event() or
          (not step.includes_subpaths and
             MapSet.member?(plain_goal_keys, {step.name, step.pathname}))
      end)
      |> Enum.map(fn candidate ->
        %{candidate | step: candidate.step |> Map.from_struct() |> Map.put(:goal_kind, nil)}
      end)

    {:ok, Enum.sort_by(goal_candidates ++ page_candidates, & &1.visitors, :desc)}
  end

  defp matches_search?(_goal, term) when byte_size(term) <= 2, do: true

  defp matches_search?(goal, term) do
    goal.display_name
    |> String.downcase()
    |> String.contains?(String.downcase(term))
  end

  defp plain_goal?(goal) do
    goal_kind(goal) == nil and
      goal.display_name == Plausible.Goal.display_name(goal.event_name, goal.page_path) and
      not String.contains?(goal.page_path || "", "*")
  end

  defp goal_step(goal) do
    %Exploration.Journey.Step{
      label: goal.display_name,
      name: goal.event_name || "pageview",
      pathname: goal.page_path || "",
      is_goal: true,
      goal_id: goal.id
    }
    |> Map.from_struct()
    |> Map.put(:goal_kind, goal_kind(goal))
  end

  @doc """
  Classifies goals which cannot be expressed with plain page or event name matching.
  """
  @spec goal_kind(Plausible.Goal.t()) :: :revenue | :scroll | :props | nil
  def goal_kind(goal) do
    cond do
      Plausible.Goal.Revenue.revenue?(goal) -> :revenue
      goal.scroll_threshold > -1 -> :scroll
      Plausible.Goal.has_custom_props?(goal) -> :props
      true -> nil
    end
  end

  defp goal_visitors(_query, []), do: %{}

  defp goal_visitors(query, goals) do
    base_query =
      query
      |> Query.set(preloaded_goals: %{all: [], matching_toplevel_filters: goals})
      |> Base.base_event_query()

    q = from(e in base_query, select: %{})

    goals
    |> Enum.reduce(q, fn goal, q ->
      goal_condition = Plausible.Stats.Goals.goal_condition(goal)

      visitors =
        dynamic([e], scale_sample(fragment("uniqIf(?, ?)", e.user_id, ^goal_condition)))

      from(e in q, select_merge: ^%{goal.id => visitors})
    end)
    |> ClickhouseRepo.one(query: query)
  end

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
    revenue_steps = revenue_steps(site, Funnel.steps(funnel))

    comparison_funnel =
      if query.comparison_utc_time_range do
        comparison_query = Comparisons.get_comparison_query(query)

        comparison_query
        |> compute(funnel, revenue_steps)
        |> recompute_flexible(comparison_query, site, funnel)
      end

    final_funnel =
      query
      |> compute(funnel, revenue_steps)
      |> recompute_flexible(query, site, funnel)

    {:ok,
     final_funnel
     |> Map.merge(%{
       name: funnel.name,
       funnel_type: funnel.funnel_type,
       comparison: comparison_funnel,
       date_range: tz_date_range(query.utc_time_range, query.timezone),
       comparison_date_range:
         if(query.comparison_utc_time_range,
           do: tz_date_range(query.comparison_utc_time_range, query.timezone)
         )
     })}
  end

  defp recompute_flexible(final_funnel, query, site, %{funnel_type: :flexible} = funnel) do
    if length(Funnel.steps(funnel)) > 2 do
      short_funnel = convert_to_first_and_last(funnel)
      revenue_steps = revenue_steps(site, Funnel.steps(short_funnel))

      [_, last_step] =
        query
        |> compute(short_funnel, revenue_steps)
        |> Map.fetch!(:steps)

      steps = List.replace_at(final_funnel.steps, -1, last_step)

      %{final_funnel | steps: steps}
    else
      final_funnel
    end
  end

  defp recompute_flexible(final_funnel, _query, _site, _funnel),
    do: final_funnel

  defp convert_to_first_and_last(funnel) do
    steps = Funnel.steps(funnel)
    Funnel.swap(funnel, funnel_type: :sequential, steps: [List.first(steps), List.last(steps)])
  end

  defp revenue_steps(site, steps) do
    if Revenue.available?(site) do
      Enum.reject(steps, &is_nil(Funnel.as_goal(&1).currency))
    else
      []
    end
  end

  defp compute(query, funnel, revenue_steps) do
    goals = Funnel.goals(funnel)

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

    revenue_totals_by_step = revenue_totals(funnel_data, revenue_steps)

    steps = backfill_steps(visitors_by_step, revenue_totals_by_step, funnel)

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

  defp select_user_revenue(db_query, []), do: db_query

  defp select_user_revenue(db_query, revenue_steps) do
    sums =
      Map.new(revenue_steps, fn step ->
        goal_condition = Plausible.Stats.Goals.goal_condition(Funnel.as_goal(step))

        {revenue_key(step),
         dynamic([e], fragment("sumIf(?, ?)", e.revenue_reporting_amount, ^goal_condition))}
      end)

    from(q in db_query, select_merge: ^sums)
  end

  defp select_revenue_totals(db_query, []), do: db_query

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

    from(q in db_query, select_merge: ^totals)
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
      Enum.reduce(Funnel.goals(funnel_definition), nil, fn goal, acc ->
        goal_condition = Plausible.Stats.Goals.goal_condition(goal)

        if acc do
          dynamic([q], fragment("?, ?", ^acc, ^goal_condition))
        else
          dynamic([q], fragment("?", ^goal_condition))
        end
      end)

    dynamic_window_funnel =
      if funnel_definition.funnel_type == :strict do
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
    max_step = Enum.max_by(Funnel.steps(funnel), & &1.step_order).step_order

    funnel
    |> Funnel.steps()
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
          label: to_string(Funnel.as_goal(step))
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
        currency = Funnel.as_goal(step).currency

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
