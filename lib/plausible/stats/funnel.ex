defmodule Plausible.Stats.Funnel do
  @moduledoc """
  Module responsible for funnel evaluation, i.e. building and executing
  ClickHouse funnel query based on `Plausible.Funnel` definition.
  """

  @funnel_window_duration 86_400

  alias Plausible.Funnel
  alias Plausible.Funnels

  import Ecto.Query

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base

  @spec funnel(Plausible.Site.t(), Plausible.Stats.Query.t(), Funnel.t() | pos_integer()) ::
          {:ok, Funnel.t()} | {:error, :funnel_not_found}
  def funnel(site, query, funnel_id) when is_integer(funnel_id) do
    case Funnels.get(site.id, funnel_id) do
      %Funnel{} = funnel ->
        funnel(site, query, funnel)

      nil ->
        {:error, :funnel_not_found}
    end
  end

  def funnel(site, query, %Funnel{} = funnel) do
    steps =
      site
      |> Base.base_event_query(query)
      |> query_funnel(funnel)
      |> backfill_steps(funnel)

    {:ok,
     %{
       name: funnel.name,
       steps: steps
     }}
  end

  defp query_funnel(query, funnel_definition) do
    q_events =
      from(e in query,
        select: %{session_id: e.session_id},
        where: e.site_id == ^funnel_definition.site_id,
        group_by: e.session_id,
        having: fragment("step > 0"),
        order_by: [desc: fragment("step")]
      )
      |> select_funnel(funnel_definition)

    query =
      from f in subquery(q_events),
        select: {f.step, count(1)},
        group_by: f.step

    ClickhouseRepo.all(query)
  end

  defp select_funnel(db_query, funnel_definition) do
    window_funnel_steps =
      Enum.reduce(funnel_definition.steps, nil, fn step, acc ->
        step_condition = step_condition(step.goal)

        if acc do
          dynamic([q], fragment("?, ?", ^acc, ^step_condition))
        else
          dynamic([q], fragment("?", ^step_condition))
        end
      end)

    dynamic_window_funnel =
      dynamic(
        [q],
        fragment("windowFunnel(?)(timestamp, ?)", @funnel_window_duration, ^window_funnel_steps)
      )

    from q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
  end

  defp step_condition(goal) do
    case goal do
      %Plausible.Goal{event_name: event} when is_binary(event) ->
        dynamic([], fragment("name = ?", ^event))

      %Plausible.Goal{page_path: pathname} when is_binary(pathname) ->
        if String.contains?(pathname, "*") do
          regex = Plausible.Stats.Base.page_regex(pathname)
          dynamic([], fragment("match(pathname, ?)", ^regex))
        else
          dynamic([], fragment("pathname = ?", ^pathname))
        end
    end
  end

  defp backfill_steps(funnel_result, funnel) do
    # Directly from ClickHouse we only get {step_idx(), visitor_count()} tuples.
    # but no totals including previous steps are aggregated.
    # Hence we need to perform the appropriate backfill
    # and also calculate dropoff and conversion rate for each step.
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

      conversion_rate =
        if current_visitors == 0 or total_visitors == 0 do
          "0.00"
        else
          current_visitors
          |> Decimal.div(total_visitors)
          |> Decimal.mult(100)
          |> Decimal.round(2)
          |> Decimal.to_string()
        end

      step = %{
        dropoff: dropoff,
        conversion_rate: conversion_rate,
        visitors: visitors_at_step,
        label: to_string(step.goal)
      }

      {total_visitors, current_visitors, [step | acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end
end
