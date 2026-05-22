defmodule Plausible.Stats.Exploration do
  @moduledoc """
  Query logic for user journey exploration.
  """

  import Ecto.Query
  import Plausible.Stats.SQL.Fragments
  import Plausible.Stats.Util, only: [percentage: 2]

  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base
  alias Plausible.Stats.Exploration.Journey
  alias Plausible.Stats.Filters
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
  @max_candidates 50

  @next_steps_defaults [
    search_term: "",
    direction: :forward,
    max_candidates: 10,
    include_wildcard?: true
  ]

  @spec max_steps() :: pos_integer()
  def max_steps, do: @max_steps

  @spec next_steps(Plausible.Site.t(), Query.t(), journey(), keyword()) ::
          {:ok, [next_step()]} | {:error, :journey_too_long}
  def next_steps(site, query, journey, opts \\ [])

  def next_steps(_site, _query, journey, _opts) when length(journey) >= @max_steps do
    {:error, :journey_too_long}
  end

  def next_steps(site, query, journey, opts) do
    opts = Keyword.merge(@next_steps_defaults, opts)
    direction = Keyword.fetch!(opts, :direction)
    search_term = Keyword.fetch!(opts, :search_term)
    max_candidates = min(Keyword.fetch!(opts, :max_candidates), @max_candidates)
    include_wilcard? = Keyword.fetch!(opts, :include_wildcard?)

    goals =
      site
      |> Plausible.Goals.for_site(include_goals_with_custom_props?: false)
      |> filter_eligible_goals()

    query
    |> Base.base_event_query()
    |> next_steps_query(journey, search_term, direction, max_candidates, include_wilcard?, goals)
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

  defp filter_eligible_goals(goals) do
    Enum.reject(goals, fn g ->
      Plausible.Goal.Revenue.revenue?(g) or g.scroll_threshold > -1 or
        Plausible.Goal.has_custom_props?(g)
    end)
  end

  defp next_steps_query(
         query,
         steps,
         search_term,
         direction,
         max_candidates,
         include_wildcard?,
         goals
       )
       when is_direction(direction) do
    next_step_idx = length(steps) + 1
    q_steps = steps_query(query, next_step_idx, direction)

    next_name = :"name#{next_step_idx}"
    next_pathname = :"pathname#{next_step_idx}"

    q_matches =
      from(s in subquery(q_steps),
        select: %{
          user_id: s.user_id,
          name: selected_as(field(s, ^next_name), :name),
          pathname: selected_as(field(s, ^next_pathname), :pathname),
          _sample_factor: fragment("any(?)", s._sample_factor)
        },
        group_by: [selected_as(:name), selected_as(:pathname), s.user_id]
      )

    q_matches =
      steps
      |> Enum.with_index()
      |> Enum.reduce(q_matches, fn {step, idx}, q ->
        step_condition = step_condition(step, idx + 1)

        from(s in q, where: ^step_condition)
      end)
      |> maybe_exclude_step_matches(List.last(steps))

    # Fan out each q_combined row into up to two output rows (exact + wildcard)
    # using ARRAY JOIN over a small boolean array.
    #
    # For each row we build [false, true] and filter it down to just [false]
    # when the wildcard row should be suppressed (non-pageview, only one distinct
    # subpath, or same visitor count as exact). ARRAY JOIN then emits one or more
    # rows per group. The joined boolean `is_wildcard` selects which values to
    # use for visitors / includes_subpaths / subpaths_count.
    q_wildcard_combined_matches =
      q_matches
      |> combined_wildcard_query(include_wildcard?)
      |> combined_wildcard_matches_query()

    q_all_combined_matches =
      if q_goal_matches = goals_query(q_matches, goals) do
        q_wildcard_combined_matches
        |> exclude_goal_matches(goals)
        |> union_all(^q_goal_matches)
      else
        q_wildcard_combined_matches
      end

    from(m in subquery(q_all_combined_matches),
      select: %{
        step: %Journey.Step{
          label:
            selected_as(
              fragment("if(? != '', ?, ?)", m.name, m.label, ^Journey.Step.journey_end_label()),
              :label
            ),
          name: fragment("if(? != '', ?, ?)", m.name, m.name, ^Journey.Step.journey_end_event()),
          pathname: m.pathname,
          includes_subpaths: m.includes_subpaths,
          subpaths_count: m.subpaths_count,
          is_goal: m.is_goal
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

  defp goals_query(_, []), do: nil

  defp goals_query(q_matches, goals) do
    values =
      Enum.map(goals, fn g ->
        pathname = g.page_path || ""

        regex_pathname =
          if String.contains?(pathname, "*") do
            Filters.Utils.page_regex(pathname)
          else
            ""
          end

        %{
          label: g.display_name,
          name: g.event_name || "pageview",
          pathname: pathname,
          regex_pathname: regex_pathname
        }
      end)

    types = %{label: :string, name: :string, pathname: :string, regex_pathname: :string}

    query =
      from(m in subquery(q_matches),
        inner_join: g in values(values, types),
        on:
          g.name == m.name and
            (g.name != "pageview" or
               (g.name == "pageview" and
                  fragment(
                    "if(? != '', match(?, ?), ? = ?)",
                    g.regex_pathname,
                    m.pathname,
                    g.regex_pathname,
                    m.pathname,
                    g.pathname
                  ))),
        select: %{
          label: selected_as(g.label, :label),
          name: selected_as(g.name, :name),
          pathname: selected_as(g.pathname, :pathname),
          visitors: scale_sample(fragment("uniq(?)", m.user_id)),
          includes_subpaths: fragment("CAST(?, 'Bool')", false),
          subpaths_count: 0,
          is_goal: fragment("CAST(?, 'Bool')", true)
        },
        group_by: [selected_as(:label), selected_as(:name), selected_as(:pathname)]
      )

    from(m in subquery(query),
      where: m.visitors > 0
    )
  end

  defp maybe_exclude_step_matches(query, %{includes_subpaths: true} = step) do
    pattern = wildcard_pattern(step.pathname)

    from m in query,
      where:
        selected_as(:name) != ^step.name or
          not fragment("match(?, ?)", selected_as(:pathname), ^pattern)
  end

  defp maybe_exclude_step_matches(query, %{is_goal: true, name: "pageview"} = step) do
    if String.contains?(step.pathname, "*") do
      pattern = Filters.Utils.page_regex(step.pathname)

      from m in query,
        where:
          selected_as(:name) != ^step.name or
            not fragment("match(?, ?)", selected_as(:pathname), ^pattern)
    else
      query
    end
  end

  defp maybe_exclude_step_matches(query, _), do: query

  defp exclude_goal_matches(query, goals) do
    to_exclude =
      goals
      |> Enum.filter(fn g -> is_nil(g.page_path) or not String.contains?(g.page_path, "*") end)
      |> Enum.map(fn g ->
        %{
          name: g.event_name || "pageview",
          pathname: g.page_path || ""
        }
      end)

    if to_exclude != [] do
      types = %{name: :string, pathname: :string}

      from m in subquery(query),
        left_join: g in values(to_exclude, types),
        on: g.name == m.name and g.pathname == m.pathname,
        where: g.name == "" or m.includes_subpaths
    else
      query
    end
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

  defp combined_wildcard_query(q_matches, true = _include_wildcard?) do
    from(em in subquery(q_matches),
      join: pname in fragment(@wildcard_array_join, em.name, em.pathname, em.pathname),
      on: true,
      hints: "ARRAY",
      where: em.name != "pageview" or selected_as(:pathname) != "",
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

  defp combined_wildcard_query(q_matches, false = _include_wildcard?) do
    from(em in subquery(q_matches),
      where: em.name != "pageview" or selected_as(:pathname) != "",
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

  defp combined_wildcard_matches_query(q_wildcard_combined) do
    from(m in subquery(q_wildcard_combined),
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
        label:
          selected_as(
            fragment(
              "if(? != 'pageview', ?, ?)",
              m.name,
              m.name,
              m.pathname
            ),
            :label
          ),
        name: selected_as(m.name, :name),
        pathname: selected_as(m.pathname, :pathname),
        visitors:
          selected_as(
            fragment("if(?, ?, ?)", is_wildcard, m.wildcard_visitors, m.exact_visitors),
            :visitors
          ),
        includes_subpaths:
          selected_as(fragment("CAST(?, 'Bool')", is_wildcard), :includes_subpaths),
        subpaths_count: fragment("if(?, ?, 0)", is_wildcard, m.subpaths_count),
        is_goal: fragment("CAST(?, 'Bool')", false)
      }
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
          pathname: fragment("if(? = 'pageview', ?, '')", e.name, e.pathname),
          timestamp: e.timestamp
        },
        where: e.name != "engagement" and e.revenue_reporting_currency == ""
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
        prev_pathname:
          lag(fragment("if(? = 'pageview', ?, '')", e.name, e.pathname)) |> over(:session_window),
        prev_name: lag(e.name) |> over(:session_window)
      }
    )
  end

  defp select_previous(query, :backward) do
    from(e in query,
      select_merge: %{
        prev_pathname:
          lead(fragment("if(? = 'pageview', ?, '')", e.name, e.pathname)) |> over(:session_window),
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
    cond do
      step.includes_subpaths ->
        pattern = wildcard_pattern(step.pathname)

        dynamic(
          [s],
          field(s, ^:"name#{count}") == ^step.name and
            fragment("match(?, ?)", field(s, ^:"pathname#{count}"), ^pattern)
        )

      step.is_goal and step.name == "pageview" and String.contains?(step.pathname, "*") ->
        pattern = Filters.Utils.page_regex(step.pathname)

        dynamic(
          [s],
          field(s, ^:"name#{count}") == ^step.name and
            fragment("match(?, ?)", field(s, ^:"pathname#{count}"), ^pattern)
        )

      step.name == Journey.Step.journey_end_event() ->
        dynamic(
          [s],
          field(s, ^:"name#{count}") == ""
        )

      true ->
        dynamic(
          [s],
          field(s, ^:"name#{count}") == ^step.name and
            field(s, ^:"pathname#{count}") == ^step.pathname
        )
    end
  end

  defp wildcard_pattern(pathname) when is_binary(pathname) do
    escaped = Regex.escape(pathname)

    "^#{escaped}(/.*)?$"
  end

  defp maybe_search(query, search_term) do
    case String.trim(search_term) do
      term when byte_size(term) > 2 ->
        from(s in query,
          where:
            ilike(selected_as(:label), ^"%#{term}%") or
              ilike(s.pathname, ^"%#{term}%") or
              (s.name != "pageview" and ilike(s.name, ^"%#{term}%"))
        )

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
