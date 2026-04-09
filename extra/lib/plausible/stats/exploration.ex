defmodule Plausible.Stats.Exploration do
  @moduledoc """
  Query logic for user journey exploration.
  """

  defmodule Journey.Step do
    @moduledoc false

    @type t() :: %__MODULE__{}

    defstruct [:name, :pathname]
  end

  import Ecto.Query
  import Plausible.Stats.SQL.Fragments

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base
  alias Plausible.Stats.Query

  @type journey() :: [Journey.Step.t()]

  @type funnel_step() :: %{
          step: Journey.Step.t(),
          visitors: pos_integer()
        }

  @spec next_steps(Query.t(), journey()) ::
          {:ok, [funnel_step()]} | {:error, :empty_journey}
  def next_steps(_query, []), do: {:error, :empty_journey}

  def next_steps(query, journey) do
    query
    |> Base.base_event_query()
    |> next_steps_query(journey)
    |> ClickhouseRepo.all()
    |> then(&{:ok, &1})
  end

  @spec journey_funnel(Query.t(), journey()) ::
          {:ok, [funnel_step()]} | {:error, :empty_journey}
  def journey_funnel(_query, []), do: {:error, :empty_journey}

  def journey_funnel(query, journey) do
    query
    |> Base.base_event_query()
    |> journey_funnel_query(journey)
    |> ClickhouseRepo.all()
    |> to_steps(journey)
    |> then(&{:ok, &1})
  end

  defp next_steps_query(query, steps) do
    next_step_idx = length(steps) + 1
    q_steps = steps_query(query, next_step_idx)

    next_name = :"name#{next_step_idx}"
    next_pathname = :"pathname#{next_step_idx}"

    q_next =
      from(s in subquery(q_steps),
        where:
          field(s, ^next_name) != "" and
            # avoid cycling back to the beginning of the exploration
            (field(s, ^next_name) != s.name1 or field(s, ^next_pathname) != s.pathname1),
        select: %{
          step: %Journey.Step{
            name: selected_as(field(s, ^next_name), :next_name),
            pathname: selected_as(field(s, ^next_pathname), :next_pathname)
          },
          visitors: selected_as(scale_sample(fragment("uniq(?)", s.user_id)), :count)
        },
        group_by: [selected_as(:next_name), selected_as(:next_pathname)],
        order_by: [
          desc: selected_as(:count),
          asc: selected_as(:next_pathname),
          asc: selected_as(:next_name)
        ],
        limit: 10
      )

    steps
    |> Enum.with_index()
    |> Enum.reduce(q_next, fn {step, idx}, q ->
      name = :"name#{idx + 1}"
      pathname = :"pathname#{idx + 1}"

      from(s in q,
        where: field(s, ^name) == ^step.name and field(s, ^pathname) == ^step.pathname
      )
    end)
  end

  defp journey_funnel_query(query, steps) do
    q_steps = steps_query(query, length(steps))

    [first_step | steps] = steps

    q_funnel =
      from(s in subquery(q_steps),
        where: s.name1 == ^first_step.name and s.pathname1 == ^first_step.pathname,
        select: %{
          1 => scale_sample(fragment("uniq(?)", s.user_id))
        }
      )

    steps
    |> Enum.with_index()
    |> Enum.reduce(q_funnel, fn {_step, idx}, q ->
      current_steps = Enum.take(steps, idx + 1)

      step_conditions =
        current_steps
        |> Enum.with_index()
        |> Enum.reduce(dynamic(true), fn {step, idx}, acc ->
          step_condition = step_condition(step, idx + 2)
          dynamic([q], fragment("? and ?", ^acc, ^step_condition))
        end)

      step_count =
        dynamic([e], scale_sample(fragment("uniqIf(?, ?)", e.user_id, ^step_conditions)))

      from(e in q, select_merge: ^%{(idx + 2) => step_count})
    end)
  end

  defp steps_query(query, steps) when is_integer(steps) do
    q_steps =
      from(e in query,
        windows: [step_window: [partition_by: e.user_id, order_by: e.timestamp]],
        select: %{
          user_id: e.user_id,
          _sample_factor: e._sample_factor,
          name1: e.name,
          pathname1: e.pathname
        },
        where: e.name != "engagement",
        order_by: e.timestamp
      )

    Enum.reduce(1..(steps - 1), q_steps, fn idx, q ->
      from(e in q,
        select_merge: %{
          ^:"name#{idx + 1}" => lead(e.name, ^idx) |> over(:step_window),
          ^:"pathname#{idx + 1}" => lead(e.pathname, ^idx) |> over(:step_window)
        }
      )
    end)
  end

  defp step_condition(step, count) do
    dynamic(
      [s],
      field(s, ^:"name#{count}") == ^step.name and
        field(s, ^:"pathname#{count}") == ^step.pathname
    )
  end

  defp to_steps([result], journey) do
    journey
    |> Enum.with_index()
    |> Enum.map(fn {step, idx} ->
      %{
        step: step,
        visitors: Map.get(result, idx + 1, 0)
      }
    end)
  end
end
