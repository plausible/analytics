defmodule Plausible.Stats.Exploration do
  @moduledoc """
  Query logic for user journey exploration.
  """

  defmodule Journey.Step do
    @moduledoc false

    @type t() :: %__MODULE__{}

    @derive {Jason.Encoder, only: [:name, :pathname]}
    defstruct [:name, :pathname]
  end

  import Ecto.Query
  import Plausible.Stats.SQL.Fragments
  import Plausible.Stats.Util, only: [percentage: 2]

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base
  alias Plausible.Stats.Query

  @type journey() :: [Journey.Step.t()]

  @type next_step() :: %{
          step: Journey.Step.t(),
          visitors: pos_integer()
        }

  @type funnel_step() :: %{
          step: Journey.Step.t(),
          visitors: non_neg_integer(),
          dropoff: non_neg_integer(),
          dropoff_percentage: String.t()
        }

  @spec next_steps(Query.t(), journey(), String.t()) ::
          {:ok, [next_step()]}
  def next_steps(query, journey, search_term \\ "")

  def next_steps(query, [], search_term) do
    query
    |> Base.base_event_query()
    |> next_steps_first_query(search_term)
    |> ClickhouseRepo.all()
    |> then(&{:ok, &1})
  end

  def next_steps(query, journey, search_term) do
    query
    |> Base.base_event_query()
    |> next_steps_query(journey, search_term)
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
    |> to_funnel(journey)
    |> then(&{:ok, &1})
  end

  defp next_steps_first_query(query, search_term) do
    q_steps = steps_query(query, 1)

    from(s in subquery(q_steps),
      where: selected_as(:next_name) != "",
      select: %{
        step: %Journey.Step{
          name: selected_as(s.name1, :next_name),
          pathname: selected_as(s.pathname1, :next_pathname)
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
    |> maybe_search(search_term)
  end

  defp next_steps_query(query, steps, search_term) do
    next_step_idx = length(steps) + 1
    q_steps = steps_query(query, next_step_idx)

    next_name = :"name#{next_step_idx}"
    next_pathname = :"pathname#{next_step_idx}"

    q_next =
      from(s in subquery(q_steps),
        # avoid cycling back to the beginning of the exploration
        where:
          selected_as(:next_name) != "" and
            (selected_as(:next_name) != s.name1 or selected_as(:next_pathname) != s.pathname1),
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
      |> maybe_search(search_term)

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

    if steps > 1 do
      Enum.reduce(1..(steps - 1), q_steps, fn idx, q ->
        from(e in q,
          select_merge: %{
            ^:"name#{idx + 1}" => lead(e.name, ^idx) |> over(:step_window),
            ^:"pathname#{idx + 1}" => lead(e.pathname, ^idx) |> over(:step_window)
          }
        )
      end)
    else
      q_steps
    end
  end

  defp step_condition(step, count) do
    dynamic(
      [s],
      field(s, ^:"name#{count}") == ^step.name and
        field(s, ^:"pathname#{count}") == ^step.pathname
    )
  end

  defp maybe_search(query, search_term) do
    case String.trim(search_term) do
      term when byte_size(term) > 2 ->
        from(s in query,
          where:
            ilike(selected_as(:next_name), ^"%#{term}%") or
              ilike(selected_as(:next_pathname), ^"%#{term}%")
        )

      _ ->
        query
    end
  end

  defp to_funnel([result], journey) do
    journey
    |> Enum.with_index()
    |> Enum.reduce(%{funnel: [], visitors_at_previous: nil}, fn {step, idx}, acc ->
      current_visitors = Map.get(result, idx + 1, 0)

      dropoff =
        if acc.visitors_at_previous, do: acc.visitors_at_previous - current_visitors, else: 0

      dropoff_percentage = percentage(dropoff, acc.visitors_at_previous)

      funnel = [
        %{
          step: step,
          visitors: current_visitors,
          dropoff: dropoff,
          dropoff_percentage: dropoff_percentage
        }
        | acc.funnel
      ]

      %{acc | funnel: funnel, visitors_at_previous: current_visitors}
    end)
    |> Map.fetch!(:funnel)
    |> Enum.reverse()
  end
end
