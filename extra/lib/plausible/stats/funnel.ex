defmodule Plausible.Stats.Funnel do
  @moduledoc """
  Module responsible for funnel evaluation, i.e. building and executing
  ClickHouse funnel query based on `Plausible.Funnel` definition.
  """

  @funnel_window_duration 86_400
  @enter_offset 40
  @max_steps 32

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
      |> Enum.into(%{})

    # Funnel definition steps are 1-indexed, if there's index 0 in the resulting query,
    # it signifies the number of visitors that haven't entered the funnel.
    not_entering_visitors = funnel_data[@enter_offset] || 0

    all_visitors =
      Enum.reduce(funnel_data, 0, fn {step, n}, acc ->
        if step >= @enter_offset do
          acc + n
        else
          acc
        end
      end)

    entering_visitors = all_visitors - not_entering_visitors

    steps = backfill_steps(funnel_data, funnel, entering_visitors)

    {:ok,
     %{
       name: funnel.name,
       steps: steps,
       all_visitors: all_visitors,
       entering_visitors: entering_visitors,
       entering_visitors_percentage: percentage(entering_visitors, all_visitors),
       never_entering_visitors: all_visitors - entering_visitors,
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

  defp select_funnel(db_query, %{open: true} = funnel_definition) do
    select_open_funnel(db_query, funnel_definition)
  end

  defp select_funnel(db_query, funnel_definition) do
    select_closed_funnel(db_query, funnel_definition)
  end

  # The closed funnel matches when a user completes 1 or more continuous steps, 
  # starting from the first step.
  #
  # The select statement returns each completed step (1-indexed). Additionally
  # it returns `@enter_offset + firstStep` special step, where `firstStep`
  # is practically either 1 (user has entered the funnel) or 0 (user has
  # not entered the funnel).
  defp select_closed_funnel(db_query, funnel_definition) do
    window_funnel_steps =
      Enum.reduce(funnel_definition.steps, nil, fn step, acc ->
        goal_condition = Plausible.Stats.Goals.goal_condition(step.goal)

        if acc do
          dynamic([q], fragment("?, ?", ^acc, ^goal_condition))
        else
          dynamic([q], fragment("?", ^goal_condition))
        end
      end)

    funnel_steps =
      dynamic(
        [q],
        fragment(
          "if(length(range(1, windowFunnel(?)(timestamp, ?) + 1) AS funArr) > 0, funArr, ?)",
          @funnel_window_duration,
          ^window_funnel_steps,
          ^[0]
        )
      )

    dynamic_window_funnel =
      dynamic(
        [q],
        fragment(
          "arrayJoin(arrayConcat(?, [funArr[1] + ?]))",
          ^funnel_steps,
          @enter_offset
        )
      )

    from(q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
    )
  end

  # The open funnel matches when a user completes 1 or more continuous steps,
  # starting from any step in the funnel.
  # 
  # First, an array or funnel subsequences (arrays) is built. Subseqeuences
  # are then checked starting from the 1st step, then from second, up until
  # a sequence with last step of the funnel only.
  #
  # There's an optimization where we exit early if we match a funnel subsequence
  # finishing at the last step of the funnel, as there's a guarantee that
  # the further, shorter ones won't return a longer matched sequence.
  #
  # Next, the longest sequence out of the checked sequences is chosen. An
  # additional step is appended computed as `@enter_offset + firstStep`
  # where `firstStep` is the step index at which the user has entered the funnel.
  # When `firstStep` is equal to 0, it means that the user has not entered
  # the funnel.
  defp select_open_funnel(db_query, funnel_definition) do
    steps_count = length(funnel_definition.steps)

    window_funnel_steps =
      Enum.map(funnel_definition.steps, &Plausible.Stats.Goals.goal_condition(&1.goal))

    offset_funnels =
      Enum.map(steps_count..1//-1, fn idx ->
        offset_steps =
          window_funnel_steps
          |> Enum.drop(idx - 1)
          |> Enum.reduce(nil, fn step, acc ->
            if acc do
              dynamic([q], fragment("?, ?", ^acc, ^step))
            else
              dynamic([q], fragment("?", ^step))
            end
          end)

        {nested_funnel(offset_steps, idx), idx}
      end)

    funnel_reduction =
      Enum.reduce(offset_funnels, dynamic([q], fragment("array()")), fn {funnel_expr, idx}, acc ->
        nested_funnel_conditional(funnel_expr, acc, idx, steps_count)
      end)

    longest_funnel =
      dynamic([q], fragment("arraySort(x -> length(x), ?)[-1]", ^funnel_reduction))

    dynamic_open_window_funnel =
      dynamic([q], fragment("? AS funSteps", ^longest_funnel))

    full_open_window_funnel =
      dynamic(
        [q],
        fragment(
          "arrayJoin(arrayPushBack(?, funSteps[1] + ?))",
          ^dynamic_open_window_funnel,
          @enter_offset
        )
      )

    from(q in db_query,
      select_merge:
        ^%{
          step: full_open_window_funnel
        }
    )
  end

  for idx <- 1..@max_steps do
    fragment_str = "range(#{idx}, windowFunnel(?)(timestamp, ?) + #{idx}) as funArr#{idx}"

    defp nested_funnel(steps, unquote(idx)) do
      dynamic(
        [q],
        fragment(
          unquote(fragment_str),
          @funnel_window_duration,
          ^steps
        )
      )
    end
  end

  for idx <- 1..@max_steps, steps <- 1..@max_steps do
    fragment_str =
      "if(length(?) >= #{steps - idx + 1}, [funArr#{idx}], arrayPushBack(?, funArr#{idx}))"

    defp nested_funnel_conditional(current_expr, inner_expr, unquote(idx), unquote(steps)) do
      dynamic(
        [q],
        fragment(
          unquote(fragment_str),
          ^current_expr,
          ^inner_expr
        )
      )
    end
  end

  defp backfill_steps(funnel_result, funnel, entering_visitors) do
    # Directly from ClickHouse we only get {step_idx(), visitor_count()} tuples.
    # but no totals including previous steps are aggregated.
    # Hence we need to perform the appropriate backfill
    # and also calculate dropoff and conversion rate for each step.
    # In case ClickHouse returns 0-index funnel result, we're going to ignore it
    # anyway, since we fold over steps as per definition, that are always
    # indexed starting from 1.

    funnel
    |> Map.fetch!(:steps)
    |> Enum.reduce({nil, []}, fn step, {visitors_at_previous, acc} ->
      # first step contains the total number of all visitors qualifying for the funnel,
      # with each subsequent step needing to accumulate sum of the previous one(s)
      visitors_at_step = Map.get(funnel_result, step.step_order, 0)

      # accumulate current_visitors for the next iteration
      current_visitors = visitors_at_step

      # Dropoff is 0 for the first step, otherwise we subtract current from previous
      dropoff = if visitors_at_previous, do: visitors_at_previous - current_visitors, else: 0

      dropoff_percentage = percentage(dropoff, visitors_at_previous)
      conversion_rate = percentage(current_visitors, entering_visitors)
      conversion_rate_step = percentage(current_visitors, visitors_at_previous)

      step = %{
        dropoff: dropoff,
        dropoff_percentage: dropoff_percentage,
        conversion_rate: conversion_rate,
        conversion_rate_step: conversion_rate_step,
        visitors: visitors_at_step,
        label: to_string(step.goal)
      }

      {current_visitors, [step | acc]}
    end)
    |> elem(1)
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
