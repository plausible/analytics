defmodule Plausible.Stats.Exploration do
  @moduledoc """
  Query logic for user journey exploration.
  """

  defmodule Journey.Step do
    @moduledoc false

    @type t() :: %__MODULE__{}

    @derive {Jason.Encoder, only: [:name, :pathname, :label]}
    defstruct [:name, :pathname, :label]

    @spec from(map()) :: t()
    def from(step) do
      new(step.name, step.pathname)
    end

    @spec new(String.t(), String.t()) :: t()
    def new(name, pathname) do
      %__MODULE__{
        label: if(name == "pageview", do: "Visit", else: name) <> " " <> pathname,
        name: name,
        pathname: pathname
      }
    end
  end

  import Ecto.Query
  import Plausible.Stats.SQL.Fragments
  import Plausible.Stats.Util, only: [percentage: 2]

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base
  alias Plausible.Stats.Query

  @type journey() :: [Journey.Step.t()]
  @type direction() :: :forward | :backward

  defguard is_direction(value) when value in [:forward, :backward]

  @type next_step() :: %{
          step: Journey.Step.t(),
          visitors: pos_integer()
        }

  @type funnel_step() :: %{
          step: Journey.Step.t(),
          visitors: non_neg_integer(),
          dropoff: non_neg_integer(),
          dropoff_percentage: String.t(),
          conversion_rate: String.t(),
          conversion_rate_step: String.t()
        }

  @next_steps_defaults [search_term: "", direction: :forward, max_candidates: 10]

  @spec next_steps(Query.t(), journey(), keyword()) :: {:ok, [next_step()]}
  def next_steps(query, journey, opts \\ []) do
    opts = Keyword.merge(@next_steps_defaults, opts)
    direction = Keyword.fetch!(opts, :direction)
    search_term = Keyword.fetch!(opts, :search_term)
    max_candidates = min(Keyword.fetch!(opts, :max_candidates), 20)

    query
    |> Base.base_event_query()
    |> next_steps_query(journey, search_term, direction, max_candidates)
    # We pass the query struct to record query metadata for
    # the CH debug console.
    |> ClickhouseRepo.all(query: query)
    |> then(&{:ok, &1})
  end

  @spec journey_funnel(Query.t(), journey(), direction()) ::
          {:ok, [funnel_step()]} | {:error, :empty_journey}
  def journey_funnel(query, journey, direction \\ :forward)

  def journey_funnel(_query, [], _direction), do: {:error, :empty_journey}

  def journey_funnel(query, journey, direction) when is_direction(direction) do
    query
    |> Base.base_event_query()
    |> journey_funnel_query(journey, direction)
    # We pass the query struct to record query metadata for
    # the CH debug console.
    |> ClickhouseRepo.all(query: query)
    |> to_funnel(journey)
    |> then(&{:ok, &1})
  end

  @doc """
  Builds a "teaser" funnel by greedily selecting steps.

  We currently don't know what the "interesting" funnel might be,
  but blindly following the most visited cascade, oftentimes results with
  a repetitive back and forth between two pages.

  Therefore we start with the most visited entry and 
  iteratively pick the most popular next step, that hasn't appeared 
  in the journey yet. Trailing slashes are ignored when 
  comparing pathnames (e.g. `/foo` and `/foo/` are treated as
  the same page - we should probably do that when deduplicating step candidates too).

  ## Options

    * `:max_steps` - maximum number of funnel steps to build (default: `6`)
    * `:max_candidates` - passed to `next_steps/3`, limiting
      how many candidate next steps are fetched per step (default: `10`)
  """
  @spec interesting_funnel(Query.t(), keyword()) ::
          {:ok, [funnel_step()]} | {:error, :not_found}
  def interesting_funnel(query, opts \\ []) do
    max_steps = min(Keyword.get(opts, :max_steps, 6), 20)
    max_candidates = min(Keyword.get(opts, :max_candidates, 10), 20)

    case build_interesting_journey(query, max_steps, max_candidates) do
      [] -> {:error, :not_found}
      journey -> journey_funnel(query, journey)
    end
  end

  defp build_interesting_journey(query, max_steps, max_candidates) do
    do_build_journey(query, [], MapSet.new(), max_steps, max_candidates)
  end

  defp do_build_journey(_query, journey, _seen, max_steps, _max_candidates)
       when length(journey) >= max_steps do
    journey
  end

  defp do_build_journey(query, journey, seen, max_steps, max_candidates) do
    {:ok, candidates} = next_steps(query, journey, max_candidates: max_candidates)

    case find_unseen_step(candidates, seen) do
      nil ->
        journey

      step ->
        new_seen = MapSet.put(seen, normalize_step_key(step))
        do_build_journey(query, journey ++ [step], new_seen, max_steps, max_candidates)
    end
  end

  defp find_unseen_step(candidates, seen) do
    Enum.find_value(candidates, fn %{step: step} ->
      if not MapSet.member?(seen, normalize_step_key(step)), do: step
    end)
  end

  defp normalize_step_key(%Journey.Step{name: name, pathname: pathname}) do
    {name, normalize_pathname(pathname)}
  end

  defp normalize_pathname("/"), do: "/"
  defp normalize_pathname(pathname), do: String.trim_trailing(pathname, "/")

  defp next_steps_query(query, steps, search_term, direction, max_candidates)
       when is_direction(direction) do
    next_step_idx = length(steps) + 1
    q_steps = steps_query(query, next_step_idx, direction)

    next_name = :"name#{next_step_idx}"
    next_pathname = :"pathname#{next_step_idx}"

    q_next =
      from(s in subquery(q_steps),
        where: selected_as(:next_name) != "",
        select: %{
          step: %Journey.Step{
            label:
              selected_as(
                fragment(
                  "concat(CASE WHEN ? = ? THEN ? ELSE ? END, ' ', ?)",
                  selected_as(:next_name),
                  "pageview",
                  "Visit",
                  selected_as(:next_name),
                  selected_as(:next_pathname)
                ),
                :next_label
              ),
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
        limit: ^max_candidates
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

  defp journey_funnel_query(query, steps, direction) do
    q_steps = steps_query(query, length(steps), direction)

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

  defp steps_query(query, steps, direction) when is_integer(steps) do
    event_ordering = [asc: :timestamp, asc: :name, asc: :pathname]

    q_pairs =
      from(e in query,
        windows: [
          session_window: [
            partition_by: e.user_id,
            order_by: ^event_ordering
          ]
        ],
        select: %{
          site_id: e.site_id,
          user_id: e.user_id,
          _sample_factor: e._sample_factor,
          name: e.name,
          pathname: e.pathname,
          timestamp: e.timestamp
        },
        where: e.name != "engagement",
        order_by: ^event_ordering
      )
      |> select_previous(direction)

    q_steps =
      from(e in subquery(q_pairs),
        windows: [step_window: [partition_by: e.user_id, order_by: ^event_ordering]],
        select: %{
          user_id: e.user_id,
          _sample_factor: e._sample_factor,
          name1: e.name,
          pathname1: e.pathname
        },
        where: e.prev_name != e.name or e.prev_pathname != e.pathname,
        order_by: ^event_ordering
      )

    if steps > 1 do
      Enum.reduce(1..(steps - 1), q_steps, fn idx, q ->
        select_next(q, idx, direction)
      end)
    else
      q_steps
    end
  end

  defp select_previous(query, :forward) do
    from(e in query,
      select_merge: %{
        prev_pathname: lag(e.pathname) |> over(:session_window),
        prev_name: lag(e.name) |> over(:session_window)
      }
    )
  end

  defp select_previous(query, :backward) do
    from(e in query,
      select_merge: %{
        prev_pathname: lead(e.pathname) |> over(:session_window),
        prev_name: lead(e.name) |> over(:session_window)
      }
    )
  end

  defp select_next(query, idx, :forward) do
    from(e in query,
      select_merge: %{
        ^:"name#{idx + 1}" => lead(e.name, ^idx) |> over(:step_window),
        ^:"pathname#{idx + 1}" => lead(e.pathname, ^idx) |> over(:step_window)
      }
    )
  end

  defp select_next(query, idx, :backward) do
    from(e in query,
      select_merge: %{
        ^:"name#{idx + 1}" => lag(e.name, ^idx) |> over(:step_window),
        ^:"pathname#{idx + 1}" => lag(e.pathname, ^idx) |> over(:step_window)
      }
    )
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
        from(s in query, where: ilike(selected_as(:next_label), ^"%#{term}%"))

      _ ->
        query
    end
  end

  defp to_funnel([result], journey) do
    journey
    |> Enum.with_index()
    |> Enum.reduce(%{funnel: [], visitors_at_previous: nil, total_visitors: nil}, fn {step, idx},
                                                                                     acc ->
      step = Journey.Step.from(step)
      current_visitors = Map.get(result, idx + 1, 0)
      total_visitors = acc.total_visitors || current_visitors

      dropoff =
        if acc.visitors_at_previous, do: acc.visitors_at_previous - current_visitors, else: 0

      dropoff_percentage = percentage(dropoff, acc.visitors_at_previous)
      conversion_rate = percentage(current_visitors, total_visitors)
      conversion_rate_step = percentage(current_visitors, acc.visitors_at_previous)

      funnel = [
        %{
          step: step,
          visitors: current_visitors,
          dropoff: dropoff,
          dropoff_percentage: dropoff_percentage,
          conversion_rate: conversion_rate,
          conversion_rate_step: conversion_rate_step
        }
        | acc.funnel
      ]

      %{
        acc
        | funnel: funnel,
          visitors_at_previous: current_visitors,
          total_visitors: total_visitors
      }
    end)
    |> Map.fetch!(:funnel)
    |> Enum.reverse()
  end
end
