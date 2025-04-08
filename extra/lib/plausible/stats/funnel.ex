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

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base

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

  def funnel(_site, query, %Funnel{} = funnel) do
    funnel_data =
      query
      |> Base.base_event_query()
      |> query_funnel(funnel)

    # Funnel definition steps are 1-indexed, if there's index 0 in the resulting query,
    # it signifies the number of visitors that haven't entered the funnel.
    not_entering_visitors =
      case funnel_data do
        [{0, count} | _] -> count
        _ -> 0
      end

    all_visitors = Enum.reduce(funnel_data, 0, fn {_, n}, acc -> acc + n end)
    steps = backfill_steps(funnel_data, funnel)

    visitors_at_first_step = List.first(steps).visitors

    {:ok,
     %{
       name: funnel.name,
       steps: steps,
       all_visitors: all_visitors,
       entering_visitors: visitors_at_first_step,
       entering_visitors_percentage: percentage(visitors_at_first_step, all_visitors),
       never_entering_visitors: all_visitors - visitors_at_first_step,
       never_entering_visitors_percentage: percentage(not_entering_visitors, all_visitors)
     }}
  end

  defp query_funnel(query, funnel_definition) do
    q_events =
      from(e in query,
        select: %{user_id: e.user_id, _sample_factor: fragment("any(_sample_factor)")},
        where: e.site_id == ^funnel_definition.site_id,
        group_by: e.user_id,
        order_by: [desc: fragment("step")]
      )
      |> select_funnel(funnel_definition)

    query =
      from(f in subquery(q_events),
        select: {f.step, total()},
        group_by: f.step
      )

    ClickhouseRepo.all(query)
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
      dynamic(
        [q],
        fragment("windowFunnel(?)(timestamp, ?)", @funnel_window_duration, ^window_funnel_steps)
      )

    from(q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
    )
  end

  defp backfill_steps(funnel_result, funnel) do
    # Directly from ClickHouse we only get {step_idx(), visitor_count()} tuples.
    # but no totals including previous steps are aggregated.
    # Hence we need to perform the appropriate backfill
    # and also calculate dropoff and conversion rate for each step.
    # In case ClickHouse returns 0-index funnel result, we're going to ignore it
    # anyway, since we fold over steps as per definition, that are always
    # indexed starting from 1.
    funnel_result = Enum.into(funnel_result, %{})
    max_step = Enum.max_by(funnel.steps, & &1.step_order).step_order

    funnel
    |> Map.fetch!(:steps)
    |> Enum.reduce({nil, nil, []}, fn step, {total_visitors, visitors_at_previous, acc} ->
      # first step contains the total number of all visitors qualifying for the funnel,
      # with each subsequent step needing to accumulate sum of the previous one(s)
      visitors_at_step =
        step.step_order..max_step
        |> Enum.map(&Map.get(funnel_result, &1, 0))
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

      step = %{
        dropoff: dropoff,
        dropoff_percentage: dropoff_percentage,
        conversion_rate: conversion_rate,
        conversion_rate_step: conversion_rate_step,
        visitors: visitors_at_step,
        label: to_string(step.goal)
      }

      {total_visitors, current_visitors, [step | acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end

  defp percentage(x, y) when x in [0, nil] or y in [0, nil] do
    "0"
  end

  defp percentage(x, y) do
    result =
      x
      |> Decimal.div(y)
      |> Decimal.mult(100)
      |> Decimal.round(2)
      |> Decimal.to_string()

    case result do
      <<compact::binary-size(1), ".00">> -> compact
      <<compact::binary-size(2), ".00">> -> compact
      <<compact::binary-size(3), ".00">> -> compact
      decimal -> decimal
    end
  end
end
