defmodule Plausible.Stats.Exploration do
  @moduledoc """
  Query logic for user journey exploration.
  """

  defmodule Journey.Step do
    @moduledoc false

    @type t() :: %__MODULE__{}

    @derive {Jason.Encoder, only: [:name, :pathname, :label, :includes_subpaths, :subpaths_count]}
    defstruct name: nil, pathname: nil, label: nil, includes_subpaths: false, subpaths_count: 0

    @spec from(map()) :: t()
    def from(step) do
      new(step.name, step.pathname, step.includes_subpaths, step.subpaths_count)
    end

    @spec new(String.t(), String.t(), boolean(), non_neg_integer()) :: t()
    def new(name, pathname, includes_subpaths \\ false, subpaths_count \\ 0)
        when is_boolean(includes_subpaths) and is_integer(subpaths_count) do
      label =
        if name != "pageview" do
          name <> " " <> pathname
        else
          pathname
        end

      %__MODULE__{
        label: label,
        name: name,
        pathname: pathname,
        includes_subpaths: includes_subpaths,
        subpaths_count: subpaths_count
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

  @max_steps 20
  @max_candidates 20

  @next_steps_defaults [
    search_term: "",
    direction: :forward,
    max_candidates: 10,
    include_wildcard?: true
  ]

  @spec max_steps() :: pos_integer()
  def max_steps, do: @max_steps

  @spec next_steps(Query.t(), journey(), keyword()) ::
          {:ok, [next_step()]} | {:error, :journey_too_long}
  def next_steps(query, journey, opts \\ [])

  def next_steps(_query, journey, _opts) when length(journey) >= @max_steps do
    {:error, :journey_too_long}
  end

  def next_steps(query, journey, opts) do
    opts = Keyword.merge(@next_steps_defaults, opts)
    direction = Keyword.fetch!(opts, :direction)
    search_term = Keyword.fetch!(opts, :search_term)
    max_candidates = min(Keyword.fetch!(opts, :max_candidates), @max_candidates)
    include_wilcard? = Keyword.fetch!(opts, :include_wildcard?)

    query
    |> Base.base_event_query()
    |> next_steps_query(journey, search_term, direction, max_candidates, include_wilcard?)
    # We pass the query struct to record query metadata for
    # the CH debug console.
    |> ClickhouseRepo.all(query: query)
    |> then(&{:ok, &1})
  end

  @spec journey_funnel(Query.t(), journey(), direction()) ::
          {:ok, [funnel_step()]} | {:error, :empty_journey | :journey_too_long}
  def journey_funnel(query, journey, direction \\ :forward)

  def journey_funnel(_query, [], _direction), do: {:error, :empty_journey}

  def journey_funnel(_query, journey, _direction) when length(journey) > @max_steps do
    {:error, :journey_too_long}
  end

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
    * `:include_wildcard?` - passed to `next_steps/3`, deciding whether
      to include implicit wildcard pathnames in suggestions or not
      (default: true)
  """
  @spec interesting_funnel(Query.t(), keyword()) ::
          {:ok, [funnel_step()]} | {:error, :not_found}
  def interesting_funnel(query, opts \\ []) do
    max_steps = min(Keyword.get(opts, :max_steps, 6), @max_steps)
    max_candidates = min(Keyword.get(opts, :max_candidates, 10), @max_candidates)

    include_wildcard? =
      Keyword.get(
        opts,
        :include_wildcard?,
        Keyword.fetch!(@next_steps_defaults, :include_wildcard?)
      )

    case build_interesting_journey(query, max_steps, max_candidates, include_wildcard?) do
      [] -> {:error, :not_found}
      journey -> journey_funnel(query, journey)
    end
  end

  defp build_interesting_journey(query, max_steps, max_candidates, include_wildcard?) do
    do_build_journey(query, [], MapSet.new(), max_steps, max_candidates, include_wildcard?)
  end

  defp do_build_journey(_query, journey, _seen, max_steps, _max_candidates, _include_wildcard?)
       when length(journey) >= max_steps do
    journey
  end

  defp do_build_journey(query, journey, seen, max_steps, max_candidates, include_wildcard?) do
    {:ok, candidates} =
      next_steps(query, journey,
        max_candidates: max_candidates,
        include_wildcard?: include_wildcard?
      )

    case find_unseen_step(candidates, seen) do
      nil ->
        journey

      step ->
        new_seen = MapSet.put(seen, normalize_step_key(step))

        do_build_journey(
          query,
          journey ++ [step],
          new_seen,
          max_steps,
          max_candidates,
          include_wildcard?
        )
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

  defp next_steps_query(query, steps, search_term, direction, max_candidates, include_wildcard?)
       when is_direction(direction) do
    next_step_idx = length(steps) + 1
    q_steps = steps_query(query, next_step_idx, direction)

    next_name = :"name#{next_step_idx}"
    next_pathname = :"pathname#{next_step_idx}"

    q_matches =
      from(s in subquery(q_steps),
        where: selected_as(:name) != "",
        select: %{
          name: selected_as(field(s, ^next_name), :name),
          pathname: selected_as(field(s, ^next_pathname), :pathname)
        }
      )

    q_matches =
      steps
      |> Enum.with_index()
      |> Enum.reduce(q_matches, fn {step, idx}, q ->
        step_condition = step_condition(step, idx + 1)

        from(s in q, where: ^step_condition)
      end)

    q_per_user_matches =
      from(m in q_matches,
        select_merge: %{user_id: m.user_id, _sample_factor: fragment("any(?)", m._sample_factor)},
        group_by: [selected_as(:name), selected_as(:pathname), m.user_id]
      )

    q_combined = combined_query(q_per_user_matches, include_wildcard?)

    # Fan out each q_combined row into up to two output rows (exact + wildcard)
    # using ARRAY JOIN over a small boolean array.
    #
    # For each row we build [false, true] and filter it down to just [false]
    # when the wildcard row should be suppressed (non-pageview, only one distinct
    # subpath, or same visitor count as exact). ARRAY JOIN then emits one or more
    # rows per group. The joined boolean `is_wildcard` selects which values to
    # use for visitors / includes_subpaths / subpaths_count.
    q_all_matches =
      from(m in subquery(q_combined),
        join:
          is_wildcard in fragment(
            """
            arrayFilter(
              x -> x = false OR (? = 'pageview' AND ? != '/' AND ? > 1 AND ? != ?),
              [false, true]
            )
            """,
            m.name,
            m.pathname,
            m.subpaths_count,
            m.wildcard_visitors,
            m.exact_visitors
          ),
        on: true,
        hints: "ARRAY",
        where: selected_as(:visitors) > 0,
        select: %{
          name: m.name,
          pathname: m.pathname,
          visitors:
            selected_as(
              fragment("if(?, ?, ?)", is_wildcard, m.wildcard_visitors, m.exact_visitors),
              :visitors
            ),
          includes_subpaths: fragment("CAST(?, 'Bool')", is_wildcard),
          subpaths_count: fragment("if(?, ?, 0)", is_wildcard, m.subpaths_count)
        }
      )

    from(m in subquery(q_all_matches),
      select: %{
        step: %Journey.Step{
          label:
            selected_as(
              fragment(
                "if(? != 'pageview', concat(?, ' ', ?), ?)",
                m.name,
                m.name,
                m.pathname,
                m.pathname
              ),
              :label
            ),
          name: m.name,
          pathname: m.pathname,
          includes_subpaths: m.includes_subpaths,
          subpaths_count: m.subpaths_count
        },
        visitors: m.visitors
      },
      order_by: [
        desc: m.visitors,
        asc: m.pathname,
        asc: m.name
      ],
      limit: ^max_candidates
    )
    |> maybe_search(search_term)
  end

  # Expand each (name, pathname, user_id) row into all prefix paths via
  # ARRAY JOIN, then aggregate once to get both exact and wildcard visitor
  # counts in a single scan of events_v2.
  #
  # The arrayFold expansion includes the original pathname as the last
  # element, so uniqIf(user_id, original_pathname = prefix_pathname) gives the
  # exact-match count for free, alongside the wildcard uniq(user_id) and the
  # uniq(original_pathname) subpath count — all in one GROUP BY.
  #
  # Non-pageview events are included in the expansion but produce only a
  # single prefix (their exact pathname), so they naturally get
  # subpaths_count = 1 and are only emitted as exact rows.
  @wildcard_array_join """
  if(? = 'pageview', arrayFold(
    acc, x -> arrayPushBack(acc, concat(acc[-1], '/', x)), 
    arraySlice(splitByChar('/', ?) AS split_pathname, 2), 
    arraySlice(split_pathname, 1, 1)), [?])
  """

  defp combined_query(q_matches, true = _include_wildcard?) do
    from(em in subquery(q_matches),
      join: pname in fragment(@wildcard_array_join, em.name, em.pathname, em.pathname),
      on: true,
      hints: "ARRAY",
      where: selected_as(:pathname) != "",
      select: %{
        name: em.name,
        pathname: selected_as(fragment("?", pname), :pathname),
        exact_visitors:
          scale_sample(fragment("uniqIf(?, ? = ?)", em.user_id, em.pathname, pname)),
        wildcard_visitors:
          selected_as(scale_sample(fragment("uniq(?)", em.user_id)), :wildcard_visitors),
        subpaths_count: scale_sample(fragment("uniq(?)", em.pathname))
      },
      group_by: [em.name, selected_as(:pathname)]
    )
  end

  defp combined_query(q_matches, false = _include_wildcard?) do
    from(em in subquery(q_matches),
      where: selected_as(:pathname) != "",
      select: %{
        name: em.name,
        pathname: selected_as(em.pathname, :pathname),
        exact_visitors:
          selected_as(scale_sample(fragment("uniq(?)", em.user_id)), :exact_visitors),
        wildcard_visitors: selected_as(:exact_visitors),
        subpaths_count: 1
      },
      group_by: [em.name, selected_as(:pathname)]
    )
  end

  defp journey_funnel_query(query, steps, direction) do
    q_steps = steps_query(query, length(steps), direction)

    q_funnel = from(s in subquery(q_steps), select: %{})

    steps
    |> Enum.with_index()
    |> Enum.reduce(q_funnel, fn
      {step, 0}, q ->
        step_condition = step_condition(step, 1)

        from(e in q,
          select_merge: %{
            1 => scale_sample(fragment("uniq(?)", e.user_id))
          },
          where: ^step_condition
        )

      {_step, idx}, q ->
        current_steps = Enum.take(steps, idx + 1)

        step_conditions =
          current_steps
          |> Enum.with_index()
          |> Enum.reduce(dynamic(true), fn {step, idx}, acc ->
            step_condition = step_condition(step, idx + 1)
            dynamic([q], fragment("? and ?", ^acc, ^step_condition))
          end)

        step_count =
          dynamic(
            [e],
            scale_sample(
              fragment(
                "uniqIf(?, ?)",
                e.user_id,
                ^step_conditions
              )
            )
          )

        from(e in q, select_merge: ^%{(idx + 1) => step_count})
    end)
  end

  defp steps_query(query, steps, direction) when is_integer(steps) do
    q_pairs =
      from(e in query,
        windows: [
          session_window: [
            partition_by: e.user_id,
            order_by: [asc: e.timestamp]
          ]
        ],
        select: %{
          site_id: e.site_id,
          user_id: e.user_id,
          _sample_factor: e._sample_factor,
          row_number: row_number() |> over(:session_window),
          name: e.name,
          pathname: e.pathname,
          timestamp: e.timestamp
        },
        where: e.name != "engagement"
      )
      |> select_previous(direction)

    q_steps =
      from(e in subquery(q_pairs),
        windows: [
          step_window: [partition_by: e.user_id, order_by: [asc: e.timestamp, asc: e.row_number]]
        ],
        select: %{
          user_id: e.user_id,
          _sample_factor: e._sample_factor,
          name1: e.name,
          pathname1: e.pathname
        },
        where: e.prev_name != e.name or e.prev_pathname != e.pathname
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
        prev_pathname:
          lead(e.pathname)
          |> over(:session_window),
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

  defp step_condition(step, count) when count <= @max_steps do
    if step.includes_subpaths do
      escaped = Regex.escape(step.pathname)

      pattern = "^#{escaped}(/.+)?$"

      dynamic(
        [s],
        field(s, ^:"name#{count}") == ^step.name and
          fragment("match(?, ?)", field(s, ^:"pathname#{count}"), ^pattern)
      )
    else
      dynamic(
        [s],
        field(s, ^:"name#{count}") == ^step.name and
          field(s, ^:"pathname#{count}") == ^step.pathname
      )
    end
  end

  defp maybe_search(query, search_term) do
    case String.trim(search_term) do
      term when byte_size(term) > 2 ->
        from(s in query, where: ilike(selected_as(:label), ^"%#{term}%"))

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
